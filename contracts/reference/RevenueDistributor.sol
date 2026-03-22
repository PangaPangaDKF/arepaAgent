// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ISavingsVault {
    function receiveYield(uint256 amount) external;
}

/**
 * @title RevenueDistributor — ArepaPay VAEM
 * @notice Recibe todos los fees del protocolo y los distribuye
 *         según el modelo VAEM:
 *
 *   25% → SavingsVault   (yield para holders de sUSDT)
 *   25% → Merchant pool  (rewards para comerciantes vía MerchantCreditPool)
 *   30% → DAT Treasury   (reinversión en liquidez del protocolo)
 *   20% → Admin reserve  (operaciones, equipo, gastos)
 *
 * También registra el volumen de pagos para que el admin pueda
 * hacer seguimiento del modelo económico completo.
 *
 * Nota sobre la fuente del fee:
 *   El PaymentProcessor descuenta 0.03% de cada pago y llama a
 *   notifyPayment() aquí. Los fondos llegan directamente de PaymentProcessor.
 */
contract RevenueDistributor is Ownable, ReentrancyGuard {
    IERC20 public immutable usdt;

    // Destinos de la distribución
    address public savingsVault;     // SavingsVault.sol
    address public merchantPool;     // MerchantCreditPool.sol
    address public datTreasury;      // DAT Treasury (multisig o contrato futuro)
    address public adminReserve;     // Wallet del admin/CEO

    // Porcentajes (en basis points, suma = 10000)
    // Modelo ArepaPay: 40% premios · 30% merchants · 25% devs · 5% reserva
    uint256 public savingsVaultShare  =  500; //  5% → Reserva de emergencia
    uint256 public merchantPoolShare  = 3000; // 30% → Red de merchants (rewards)
    uint256 public datTreasuryShare   = 4000; // 40% → Pool de premios (helados, moto, etc.)
    uint256 public adminReserveShare  = 2500; // 25% → Devs / Mantenimiento / Desarrollo

    // Estadísticas
    uint256 public totalFeesReceived;
    uint256 public totalToSavingsVault;
    uint256 public totalToMerchantPool;
    uint256 public totalToDAT;
    uint256 public totalToAdmin;
    uint256 public totalPaymentVolume;   // USDT total movido (para métricas)
    uint256 public totalPaymentCount;

    // Balance pendiente de distribución (si distribute() no se llama inmediatamente)
    uint256 public pendingDistribution;

    event FeesReceived(address indexed from, uint256 amount);
    event FeesDistributed(
        uint256 toVault,
        uint256 toMerchants,
        uint256 toDAT,
        uint256 toAdmin
    );
    event PaymentRecorded(address indexed payer, address indexed merchant, uint256 amount, uint256 fee);
    event DestinationsUpdated();
    event SharesUpdated(uint256 vault, uint256 merchants, uint256 dat, uint256 admin);

    constructor(
        address _usdt,
        address _datTreasury,
        address _adminReserve
    ) Ownable(msg.sender) {
        usdt = IERC20(_usdt);
        datTreasury = _datTreasury;
        adminReserve = _adminReserve;
        // savingsVault y merchantPool se setean después del deploy
    }

    // ─────────────────────────────────────────────
    //  Setup (llamar después de deployar los demás contratos)
    // ─────────────────────────────────────────────

    function setDestinations(
        address _savingsVault,
        address _merchantPool
    ) external onlyOwner {
        require(_savingsVault != address(0), "RD: vault invalida");
        require(_merchantPool != address(0), "RD: pool invalida");
        savingsVault = _savingsVault;
        merchantPool = _merchantPool;
        emit DestinationsUpdated();
    }

    function setDATTreasury(address _dat) external onlyOwner {
        require(_dat != address(0), "RD: dat invalido");
        datTreasury = _dat;
    }

    function setAdminReserve(address _admin) external onlyOwner {
        require(_admin != address(0), "RD: admin invalido");
        adminReserve = _admin;
    }

    // ─────────────────────────────────────────────
    //  Recepción de fees
    // ─────────────────────────────────────────────

    /**
     * @notice PaymentProcessor llama esto cuando procesa un pago.
     *         Los USDT del fee ya fueron transferidos a este contrato.
     * @param payer Quien pagó
     * @param merchant Quien cobró
     * @param paymentAmount Monto total del pago (antes del fee)
     * @param feeAmount Fee descontado (0.03% del pago)
     */
    function notifyPayment(
        address payer,
        address merchant,
        uint256 paymentAmount,
        uint256 feeAmount
    ) external {
        // En producción: require(msg.sender == paymentProcessor, "RD: no autorizado");
        // Por ahora: cualquiera puede notificar (ajustar en Fase 2)

        totalFeesReceived += feeAmount;
        totalPaymentVolume += paymentAmount;
        totalPaymentCount += 1;
        pendingDistribution += feeAmount;

        emit FeesReceived(msg.sender, feeAmount);
        emit PaymentRecorded(payer, merchant, paymentAmount, feeAmount);

        // Distribuir automáticamente si hay suficiente acumulado
        if (pendingDistribution >= 1e6) { // 1 USDT mínimo para distribuir
            _distribute();
        }
    }

    /**
     * @notice Admin puede forzar la distribución manualmente en cualquier momento.
     */
    function distribute() external onlyOwner nonReentrant {
        require(pendingDistribution > 0, "RD: nada que distribuir");
        _distribute();
    }

    // ─────────────────────────────────────────────
    //  Distribución interna
    // ─────────────────────────────────────────────

    function _distribute() internal {
        uint256 total = pendingDistribution;
        if (total == 0) return;

        pendingDistribution = 0;

        uint256 toVault     = (total * savingsVaultShare)  / 10000;
        uint256 toMerchants = (total * merchantPoolShare)  / 10000;
        uint256 toDAT       = (total * datTreasuryShare)   / 10000;
        uint256 toAdmin     = total - toVault - toMerchants - toDAT; // remainder al admin

        // → SavingsVault (activa receiveYield para subir el precio de sUSDT)
        if (toVault > 0 && savingsVault != address(0)) {
            usdt.approve(savingsVault, toVault);
            ISavingsVault(savingsVault).receiveYield(toVault);
            totalToSavingsVault += toVault;
        }

        // → MerchantCreditPool (se acumula allí para rewards)
        if (toMerchants > 0 && merchantPool != address(0)) {
            usdt.transfer(merchantPool, toMerchants);
            totalToMerchantPool += toMerchants;
        }

        // → DAT Treasury
        if (toDAT > 0 && datTreasury != address(0)) {
            usdt.transfer(datTreasury, toDAT);
            totalToDAT += toDAT;
        }

        // → Admin reserve
        if (toAdmin > 0 && adminReserve != address(0)) {
            usdt.transfer(adminReserve, toAdmin);
            totalToAdmin += toAdmin;
        }

        emit FeesDistributed(toVault, toMerchants, toDAT, toAdmin);
    }

    // ─────────────────────────────────────────────
    //  Admin: ajustar porcentajes
    // ─────────────────────────────────────────────

    /**
     * @notice Cambiar la distribución de fees.
     *         La suma DEBE ser exactamente 10000 (100%).
     */
    function setShares(
        uint256 _vault,
        uint256 _merchants,
        uint256 _dat,
        uint256 _admin
    ) external onlyOwner {
        require(_vault + _merchants + _dat + _admin == 10000, "RD: suma != 100%");
        savingsVaultShare = _vault;
        merchantPoolShare = _merchants;
        datTreasuryShare  = _dat;
        adminReserveShare = _admin;
        emit SharesUpdated(_vault, _merchants, _dat, _admin);
    }

    // ─────────────────────────────────────────────
    //  Vistas
    // ─────────────────────────────────────────────

    function getStats() external view returns (
        uint256 feesTotal,
        uint256 volumeTotal,
        uint256 txCount,
        uint256 avgTxSize
    ) {
        return (
            totalFeesReceived,
            totalPaymentVolume,
            totalPaymentCount,
            totalPaymentCount > 0 ? totalPaymentVolume / totalPaymentCount : 0
        );
    }

    function getCurrentShares() external view returns (
        uint256 vault, uint256 merchants, uint256 dat, uint256 admin
    ) {
        return (savingsVaultShare, merchantPoolShare, datTreasuryShare, adminReserveShare);
    }

    /**
     * @notice APY estimado para sUSDT según el volumen reciente.
     *         Solo estimación — el APY real depende del TVL en el vault.
     * @param vaultTVL USDT depositados en el vault actualmente
     */
    function estimatedVaultAPY(uint256 vaultTVL) external view returns (uint256 apyBps) {
        if (vaultTVL == 0 || totalPaymentCount == 0) return 0;
        // Proyectar ingresos anuales al vault
        uint256 avgDailyFee = totalFeesReceived / ((block.timestamp - 1) / 86400 + 1);
        uint256 annualToVault = (avgDailyFee * 365 * savingsVaultShare) / 10000;
        return (annualToVault * 10000) / vaultTVL;
    }
}
