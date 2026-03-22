// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 }  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title OTCMarket
 * @notice Mercado P2P donde el comerciante vende USDT al usuario a cambio de Bs en efectivo.
 *
 * Flujo:
 *  1. Merchant llama createOffer(amount, priceCents) → USDT queda bloqueado en escrow.
 *  2. Usuario llama reserveOffer(offerId) → reserva la oferta.
 *  3. Usuario paga al merchant en Bs FÍSICOS (off-chain, en persona).
 *  4. Merchant llama confirmSale(offerId) → USDT liberado al usuario. ✓
 *     — O —
 *     Si el merchant no confirma en TIMEOUT segundos:
 *     Usuario llama cancelReservation(offerId) → USDT devuelto al merchant. ✗
 *  5. Merchant puede cancelar una oferta NO reservada con cancelOffer(offerId).
 *
 * Seguridad:
 *  - USDT siempre en escrow (nunca en la cuenta del merchant ni del usuario hasta confirmar)
 *  - Límite de tiempo de reserva (RESERVATION_TIMEOUT = 30 min)
 *  - Solo merchants autorizados por el owner pueden crear ofertas
 *  - El owner puede cancelar cualquier oferta en caso de disputa
 */
contract OTCMarket is Ownable {

    IERC20 public immutable usdt;

    uint256 public constant RESERVATION_TIMEOUT = 30 minutes;

    enum OfferStatus { Open, Reserved, Completed, Cancelled }

    struct Offer {
        address  merchant;
        uint256  usdtAmount;    // USDT en escrow (6 decimales)
        uint256  priceCents;    // Bs por USDT en centavos (ej: 4200000 = 42.000 Bs/USDT)
        address  buyer;         // quien reservó (address(0) si Open)
        uint256  reservedAt;    // timestamp de la reserva
        OfferStatus status;
    }

    mapping(uint256 => Offer) public offers;
    mapping(address => bool)  public authorizedMerchants;
    uint256 public nextOfferId;

    // ── Eventos ───────────────────────────────────────────────────────────────
    event OfferCreated(uint256 indexed offerId, address indexed merchant, uint256 usdtAmount, uint256 priceCents);
    event OfferReserved(uint256 indexed offerId, address indexed buyer, uint256 reservedAt);
    event SaleConfirmed(uint256 indexed offerId, address indexed buyer, uint256 usdtAmount);
    event ReservationCancelled(uint256 indexed offerId, string reason);
    event OfferCancelled(uint256 indexed offerId);
    event MerchantAuthorized(address indexed merchant, bool status);

    // ── Constructor ───────────────────────────────────────────────────────────
    constructor(address _usdt) Ownable(msg.sender) {
        require(_usdt != address(0), "OTC: zero usdt");
        usdt = IERC20(_usdt);
    }

    // ── Admin ─────────────────────────────────────────────────────────────────

    function authorizeMerchant(address _merchant, bool _status) external onlyOwner {
        require(_merchant != address(0), "OTC: zero address");
        authorizedMerchants[_merchant] = _status;
        emit MerchantAuthorized(_merchant, _status);
    }

    /// El owner puede cancelar cualquier oferta (resolución de disputa)
    function adminCancel(uint256 _offerId) external onlyOwner {
        Offer storage o = offers[_offerId];
        require(o.status == OfferStatus.Open || o.status == OfferStatus.Reserved, "OTC: not cancellable");
        o.status = OfferStatus.Cancelled;
        usdt.transfer(o.merchant, o.usdtAmount);
        emit OfferCancelled(_offerId);
    }

    // ── Merchant: crear oferta ────────────────────────────────────────────────

    /**
     * @notice Crea una oferta de venta de USDT.
     *         El USDT se bloquea en el contrato inmediatamente.
     * @param _usdtAmount  Cantidad de USDT a vender (6 decimales)
     * @param _priceCents  Precio en centavos de Bs por USDT
     *                     Ej: 4200000 = 42.000 Bs por 1 USDT
     */
    function createOffer(uint256 _usdtAmount, uint256 _priceCents) external returns (uint256 offerId) {
        require(authorizedMerchants[msg.sender], "OTC: not authorized merchant");
        require(_usdtAmount > 0, "OTC: amount must be > 0");
        require(_priceCents > 0, "OTC: price must be > 0");

        usdt.transferFrom(msg.sender, address(this), _usdtAmount);

        offerId = nextOfferId++;
        offers[offerId] = Offer({
            merchant:    msg.sender,
            usdtAmount:  _usdtAmount,
            priceCents:  _priceCents,
            buyer:       address(0),
            reservedAt:  0,
            status:      OfferStatus.Open
        });

        emit OfferCreated(offerId, msg.sender, _usdtAmount, _priceCents);
    }

    /**
     * @notice El merchant cancela una oferta que aún nadie reservó.
     */
    function cancelOffer(uint256 _offerId) external {
        Offer storage o = offers[_offerId];
        require(o.merchant == msg.sender, "OTC: not your offer");
        require(o.status == OfferStatus.Open, "OTC: offer not open");
        o.status = OfferStatus.Cancelled;
        usdt.transfer(msg.sender, o.usdtAmount);
        emit OfferCancelled(_offerId);
    }

    // ── Usuario: reservar oferta ──────────────────────────────────────────────

    /**
     * @notice El usuario reserva una oferta.
     *         A partir de aquí tiene RESERVATION_TIMEOUT para pagar en efectivo al merchant.
     */
    function reserveOffer(uint256 _offerId) external {
        Offer storage o = offers[_offerId];
        require(o.status == OfferStatus.Open, "OTC: offer not open");
        require(o.merchant != msg.sender, "OTC: cannot reserve own offer");

        o.buyer      = msg.sender;
        o.reservedAt = block.timestamp;
        o.status     = OfferStatus.Reserved;

        emit OfferReserved(_offerId, msg.sender, block.timestamp);
    }

    /**
     * @notice El usuario cancela su reserva si todavía no expiró el timeout.
     *         El USDT regresa al merchant.
     */
    function cancelReservation(uint256 _offerId) external {
        Offer storage o = offers[_offerId];
        require(o.status == OfferStatus.Reserved, "OTC: not reserved");
        require(
            o.buyer == msg.sender || block.timestamp >= o.reservedAt + RESERVATION_TIMEOUT,
            "OTC: not buyer or not expired"
        );

        address merchant = o.merchant;
        o.status = OfferStatus.Cancelled;
        usdt.transfer(merchant, o.usdtAmount);

        string memory reason = (o.buyer == msg.sender) ? "buyer_cancelled" : "timeout";
        emit ReservationCancelled(_offerId, reason);
    }

    // ── Merchant: confirmar venta ─────────────────────────────────────────────

    /**
     * @notice El merchant confirma que recibió el pago en Bs.
     *         Libera el USDT bloqueado al comprador.
     */
    function confirmSale(uint256 _offerId) external {
        Offer storage o = offers[_offerId];
        require(o.merchant == msg.sender, "OTC: not your offer");
        require(o.status == OfferStatus.Reserved, "OTC: not reserved");
        require(block.timestamp < o.reservedAt + RESERVATION_TIMEOUT, "OTC: reservation expired");

        address buyer   = o.buyer;
        uint256 amount  = o.usdtAmount;
        o.status        = OfferStatus.Completed;

        usdt.transfer(buyer, amount);
        emit SaleConfirmed(_offerId, buyer, amount);
    }

    // ── Views ─────────────────────────────────────────────────────────────────

    function getOffer(uint256 _offerId) external view returns (Offer memory) {
        return offers[_offerId];
    }

    /// Devuelve los IDs de todas las ofertas abiertas (max 50 para no romper gas)
    function getOpenOffers() external view returns (uint256[] memory) {
        uint256 count;
        uint256 total = nextOfferId;
        for (uint256 i = 0; i < total && i < 200; i++) {
            if (offers[i].status == OfferStatus.Open) count++;
        }
        uint256[] memory result = new uint256[](count);
        uint256 idx;
        for (uint256 i = 0; i < total && i < 200; i++) {
            if (offers[i].status == OfferStatus.Open) result[idx++] = i;
        }
        return result;
    }

    /// Precio total en Bs que el usuario debe pagar por una oferta
    function totalPriceBs(uint256 _offerId) external view returns (uint256) {
        Offer storage o = offers[_offerId];
        // usdtAmount tiene 6 decimales → dividir entre 1e6 para obtener USDT entero
        // priceCents en centavos → dividir entre 100 para obtener Bs enteros
        return (o.usdtAmount * o.priceCents) / (1e6 * 100);
    }
}
