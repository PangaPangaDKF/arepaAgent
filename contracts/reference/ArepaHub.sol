// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 }  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ArepaHub
 * @notice Entidad central del ecosistema ArepaPay.
 *
 * Responsabilidades:
 *  1. El admin (fundador) inyecta USDT a la red.
 *  2. El admin vende USDT a los comerciantes (precio = tasaBCV + margenAdmin%).
 *  3. El admin recompra USDT excedente de los comerciantes.
 *  4. Rastrea: depositado / ganado / retirado por comerciante
 *     → un comerciante no puede retirar más de lo que depositó + ganó.
 *  5. Límite diario de venta por comerciante (anti-vaciado).
 *  6. El admin puede actualizar la tasa BCV manualmente.
 *
 * Flujo económico:
 *   Admin  ──inject()──► Hub (treasury)
 *   Admin  ──supplyMerchant()──► Merchant recibe USDT
 *   Merchant paga en Bs off-chain al Admin
 *   Merchant ──sellToHub()──► Admin recompra USDT excedente del merchant
 */
contract ArepaHub is Ownable {

    IERC20 public immutable usdt;

    // ── Precio ────────────────────────────────────────────────────────────────
    // Precio en centavos de Bs por 1 USDT  (ej: 4200000 = 42.000 Bs)
    // Se divide por 100 en la vista para dar 2 decimales de Bs
    uint256 public bcvRateCents;       // tasa BCV oficial en centavos Bs/USDT
    uint256 public adminMarginBps;     // margen del admin sobre BCV (bps, 100 = 1%)
    // Precio al que el admin le vende al merchant = bcvRateCents * (10000 + adminMarginBps) / 10000

    // ── Límite diario por merchant ────────────────────────────────────────────
    uint256 public dailyLimitUSDT = 500 * 1e6;   // 500 USDT por defecto (6 decimales)

    struct MerchantAccount {
        uint256 supplied;    // USDT total que el admin le ha vendido
        uint256 earned;      // USDT ganado en comisiones de la red
        uint256 withdrawn;   // USDT que el merchant le ha vendido de vuelta al hub
        uint256 dayStart;    // timestamp del inicio del día actual
        uint256 dayVolume;   // USDT vendido hoy por este merchant
        bool    authorized;  // está activo en el hub
    }

    mapping(address => MerchantAccount) public merchants;

    // ── Eventos ───────────────────────────────────────────────────────────────
    event Injected(uint256 amount);
    event MerchantAuthorized(address indexed merchant, bool status);
    event MerchantSupplied(address indexed merchant, uint256 usdtAmount, uint256 priceCents);
    event MerchantSoldToHub(address indexed merchant, uint256 usdtAmount);
    event EarningsAdded(address indexed merchant, uint256 amount);
    event BcvRateUpdated(uint256 newRateCents);
    event AdminMarginUpdated(uint256 newMarginBps);
    event DailyLimitUpdated(uint256 newLimit);

    // ── Constructor ───────────────────────────────────────────────────────────
    constructor(address _usdt, uint256 _bcvRateCents, uint256 _adminMarginBps)
        Ownable(msg.sender)
    {
        require(_usdt != address(0), "Hub: zero usdt");
        usdt = IERC20(_usdt);
        bcvRateCents    = _bcvRateCents;
        adminMarginBps  = _adminMarginBps;
    }

    // ── Admin: configuración ──────────────────────────────────────────────────

    function setBcvRate(uint256 _rateCents) external onlyOwner {
        require(_rateCents > 0, "Hub: rate must be > 0");
        bcvRateCents = _rateCents;
        emit BcvRateUpdated(_rateCents);
    }

    function setAdminMargin(uint256 _marginBps) external onlyOwner {
        require(_marginBps <= 1000, "Hub: margin too high (max 10%)");
        adminMarginBps = _marginBps;
        emit AdminMarginUpdated(_marginBps);
    }

    function setDailyLimit(uint256 _limit) external onlyOwner {
        dailyLimitUSDT = _limit;
        emit DailyLimitUpdated(_limit);
    }

    function authorizeMerchant(address _merchant, bool _status) external onlyOwner {
        require(_merchant != address(0), "Hub: zero address");
        merchants[_merchant].authorized = _status;
        emit MerchantAuthorized(_merchant, _status);
    }

    // ── Admin: inyectar liquidez al hub ───────────────────────────────────────

    /**
     * @notice El admin transfiere USDT al contrato (incrementa el treasury).
     *         Requiere approve previo de USDT.
     */
    function inject(uint256 amount) external onlyOwner {
        require(amount > 0, "Hub: amount must be > 0");
        usdt.transferFrom(msg.sender, address(this), amount);
        emit Injected(amount);
    }

    // ── Admin: vender USDT a un merchant ──────────────────────────────────────

    /**
     * @notice El admin le transfiere USDT a un merchant autorizado.
     *         El merchant le paga al admin en Bs off-chain.
     *         Registra la cantidad en la cuenta del merchant.
     */
    function supplyMerchant(address _merchant, uint256 _usdtAmount) external onlyOwner {
        require(merchants[_merchant].authorized, "Hub: merchant not authorized");
        require(_usdtAmount > 0, "Hub: amount must be > 0");
        require(usdt.balanceOf(address(this)) >= _usdtAmount, "Hub: insufficient treasury");

        merchants[_merchant].supplied += _usdtAmount;

        usdt.transfer(_merchant, _usdtAmount);
        emit MerchantSupplied(_merchant, _usdtAmount, sellPriceCents());
    }

    // ── Merchant: vender USDT excedente de vuelta al hub ─────────────────────

    /**
     * @notice El merchant vende USDT de vuelta al hub.
     *         Solo puede vender hasta lo que depositó + ganó - ya vendido.
     *         Respeta el límite diario.
     */
    function sellToHub(uint256 _usdtAmount) external {
        MerchantAccount storage acc = merchants[msg.sender];
        require(acc.authorized, "Hub: not authorized merchant");
        require(_usdtAmount > 0, "Hub: amount must be > 0");

        uint256 allowed = acc.supplied + acc.earned - acc.withdrawn;
        require(_usdtAmount <= allowed, "Hub: exceeds allowed withdrawal");

        // Reset diario
        if (block.timestamp >= acc.dayStart + 1 days) {
            acc.dayStart  = block.timestamp;
            acc.dayVolume = 0;
        }
        require(acc.dayVolume + _usdtAmount <= dailyLimitUSDT, "Hub: daily limit reached");

        acc.withdrawn  += _usdtAmount;
        acc.dayVolume  += _usdtAmount;

        usdt.transferFrom(msg.sender, address(this), _usdtAmount);
        emit MerchantSoldToHub(msg.sender, _usdtAmount);
    }

    // ── Interno: registrar earnings de comisiones ────────────────────────────

    /**
     * @notice Registra comisiones ganadas por el merchant (llamado por RevenueDistributor).
     *         No transfiere tokens — solo actualiza el tracking.
     */
    function recordEarnings(address _merchant, uint256 _amount) external onlyOwner {
        merchants[_merchant].earned += _amount;
        emit EarningsAdded(_merchant, _amount);
    }

    // ── Admin: retirar USDT del treasury ─────────────────────────────────────

    function withdrawTreasury(uint256 _amount) external onlyOwner {
        require(usdt.balanceOf(address(this)) >= _amount, "Hub: insufficient balance");
        usdt.transfer(msg.sender, _amount);
    }

    // ── Views ─────────────────────────────────────────────────────────────────

    /// Precio de venta del admin al merchant (centavos Bs por USDT)
    function sellPriceCents() public view returns (uint256) {
        return bcvRateCents * (10000 + adminMarginBps) / 10000;
    }

    /// Cuánto USDT puede retirar un merchant todavía
    function maxWithdrawable(address _merchant) external view returns (uint256) {
        MerchantAccount storage acc = merchants[_merchant];
        uint256 total = acc.supplied + acc.earned;
        if (total <= acc.withdrawn) return 0;
        return total - acc.withdrawn;
    }

    /// Balance USDT del treasury
    function treasuryBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
}
