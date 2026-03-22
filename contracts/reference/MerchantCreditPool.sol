// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title MerchantCreditPool — ArepaPay VAEM
 * @notice Gestiona la liquidez que el admin provee a los comerciantes.
 *
 * MODELO:
 *   - Admin deposita USDT al pool como proveedor de liquidez
 *   - Admin asigna cupos (credit limit) a comerciantes aprobados
 *   - Comerciante retira hasta su cupo (crédito)
 *   - Comerciante devuelve USDT con un pequeño interés (2-5% mensual)
 *   - Comerciante gana "merchant rewards" = % de su volumen procesado
 *   - Más volumen procesado = mayor credit score = mayor cupo
 *
 * SISTEMA DE PUNTUACIÓN (Credit Score):
 *   Score 1 (Nuevo):    cupo máx $100 USDT
 *   Score 2 (Junior):   cupo máx $500 USDT
 *   Score 3 (Senior):   cupo máx $2,000 USDT
 *   Score 4 (Gold):     cupo máx $10,000 USDT
 *   Score 5 (Platinum): cupo máx ilimitado (solo bajo aprobación manual)
 *
 * INTERÉS:
 *   El interés NO es on-chain en esta versión.
 *   Se maneja off-chain: el admin simplemente descuenta del siguiente cupo asignado.
 *   Esto evita complejidad innecesaria para el MVP.
 */
contract MerchantCreditPool is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ADMIN_ROLE    = keccak256("ADMIN_ROLE");
    bytes32 public constant MERCHANT_ROLE = keccak256("MERCHANT_ROLE");

    IERC20 public immutable usdt;

    // ─── Estructura del comerciante ───
    struct Merchant {
        bool    active;
        uint8   creditScore;        // 1-5
        uint256 creditLimit;        // USDT máximo que puede tener en uso
        uint256 creditUsed;         // USDT actualmente retirado
        uint256 totalVolumeProcessed; // USDT total pagado por usuarios a este merchant
        uint256 totalRewardsEarned; // USDT acumulado en recompensas (retirable)
        uint256 rewardsPaid;        // USDT de rewards ya retirados
        uint256 joinedAt;
        string  name;               // Nombre del negocio
    }

    mapping(address => Merchant) public merchants;
    address[] public merchantList;

    // Pool de liquidez del admin
    uint256 public poolBalance;         // USDT disponible para prestar
    uint256 public totalCreditOut;      // USDT actualmente prestado
    uint256 public totalRewardsPending; // USDT en rewards pendientes de retiro

    // Parámetros configurables
    uint256 public rewardRatePerTx = 10; // basis points: 10/10000 = 0.10% de cada pago va a rewards del merchant
    uint256[6] public scoreCreditCaps = [0, 100e6, 500e6, 2000e6, 10_000e6, type(uint256).max];
    // scoreCreditCaps[1] = $100 USDT, [2] = $500, [3] = $2,000, [4] = $10,000, [5] = sin límite

    // ─── Eventos ───
    event MerchantRegistered(address indexed merchant, string name, uint8 initialScore);
    event MerchantDeactivated(address indexed merchant, string reason);
    event CreditLimitUpdated(address indexed merchant, uint256 oldLimit, uint256 newLimit);
    event CreditScoreUpdated(address indexed merchant, uint8 oldScore, uint8 newScore);
    event CreditWithdrawn(address indexed merchant, uint256 amount);
    event CreditRepaid(address indexed merchant, uint256 amount);
    event RewardAccrued(address indexed merchant, uint256 usdtReward, uint256 paymentAmount);
    event RewardWithdrawn(address indexed merchant, uint256 amount);
    event AdminDeposited(address indexed admin, uint256 amount);
    event AdminWithdrew(address indexed admin, uint256 amount);
    event VolumeRecorded(address indexed merchant, uint256 paymentAmount);

    constructor(address _usdt) {
        usdt = IERC20(_usdt);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ─────────────────────────────────────────────
    //  Admin: gestión del pool de liquidez
    // ─────────────────────────────────────────────

    /**
     * @notice Admin deposita USDT al pool para financiar merchants.
     */
    function adminDeposit(uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount > 0, "MCP: amount = 0");
        usdt.transferFrom(msg.sender, address(this), amount);
        poolBalance += amount;
        emit AdminDeposited(msg.sender, amount);
    }

    /**
     * @notice Admin retira USDT disponible del pool (no el que está prestado).
     */
    function adminWithdraw(uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount <= poolBalance, "MCP: saldo insuficiente en pool");
        poolBalance -= amount;
        usdt.transfer(msg.sender, amount);
        emit AdminWithdrew(msg.sender, amount);
    }

    // ─────────────────────────────────────────────
    //  Admin: gestión de comerciantes
    // ─────────────────────────────────────────────

    /**
     * @notice Registrar un nuevo comerciante.
     * @param merchant Dirección wallet del comerciante
     * @param name Nombre del negocio (informativo)
     * @param initialScore Credit score inicial (1-4, 5 requiere aprobación especial)
     */
    function registerMerchant(
        address merchant,
        string calldata name,
        uint8 initialScore
    ) external onlyRole(ADMIN_ROLE) {
        require(merchant != address(0), "MCP: address invalida");
        require(!merchants[merchant].active, "MCP: ya registrado");
        require(initialScore >= 1 && initialScore <= 4, "MCP: score invalido (1-4)");

        uint256 limit = scoreCreditCaps[initialScore];

        merchants[merchant] = Merchant({
            active: true,
            creditScore: initialScore,
            creditLimit: limit,
            creditUsed: 0,
            totalVolumeProcessed: 0,
            totalRewardsEarned: 0,
            rewardsPaid: 0,
            joinedAt: block.timestamp,
            name: name
        });

        merchantList.push(merchant);
        _grantRole(MERCHANT_ROLE, merchant);

        emit MerchantRegistered(merchant, name, initialScore);
    }

    /**
     * @notice Desactivar un comerciante (no puede retirar más crédito).
     *         Su crédito pendiente de devolver sigue registrado.
     */
    function deactivateMerchant(address merchant, string calldata reason)
        external onlyRole(ADMIN_ROLE)
    {
        require(merchants[merchant].active, "MCP: no activo");
        merchants[merchant].active = false;
        _revokeRole(MERCHANT_ROLE, merchant);
        emit MerchantDeactivated(merchant, reason);
    }

    /**
     * @notice Actualizar el credit score de un comerciante.
     *         El límite se actualiza automáticamente según el nuevo score.
     */
    function updateCreditScore(address merchant, uint8 newScore)
        external onlyRole(ADMIN_ROLE)
    {
        require(merchants[merchant].active, "MCP: no activo");
        require(newScore >= 1 && newScore <= 5, "MCP: score invalido");

        uint8 oldScore = merchants[merchant].creditScore;
        uint256 oldLimit = merchants[merchant].creditLimit;
        uint256 newLimit = (newScore == 5)
            ? type(uint256).max
            : scoreCreditCaps[newScore];

        merchants[merchant].creditScore = newScore;
        merchants[merchant].creditLimit = newLimit;

        emit CreditScoreUpdated(merchant, oldScore, newScore);
        emit CreditLimitUpdated(merchant, oldLimit, newLimit);
    }

    /**
     * @notice El admin puede ajustar el límite de crédito manualmente
     *         sin cambiar el score (ej: para dar un bono temporal).
     */
    function setCreditLimit(address merchant, uint256 newLimit)
        external onlyRole(ADMIN_ROLE)
    {
        require(merchants[merchant].active, "MCP: no activo");
        uint256 oldLimit = merchants[merchant].creditLimit;
        merchants[merchant].creditLimit = newLimit;
        emit CreditLimitUpdated(merchant, oldLimit, newLimit);
    }

    // ─────────────────────────────────────────────
    //  Comerciante: crédito
    // ─────────────────────────────────────────────

    /**
     * @notice Comerciante retira USDT del pool (hasta su cupo disponible).
     *         Este USDT es un "crédito" — debe ser devuelto.
     */
    function withdrawCredit(uint256 amount)
        external onlyRole(MERCHANT_ROLE) nonReentrant whenNotPaused
    {
        Merchant storage m = merchants[msg.sender];
        require(m.active, "MCP: comerciante inactivo");
        require(amount > 0, "MCP: amount = 0");

        uint256 available = m.creditLimit - m.creditUsed;
        require(amount <= available, "MCP: excede cupo disponible");
        require(amount <= poolBalance, "MCP: pool sin liquidez suficiente");

        m.creditUsed += amount;
        poolBalance -= amount;
        totalCreditOut += amount;

        usdt.transfer(msg.sender, amount);

        emit CreditWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Comerciante devuelve USDT al pool (repago del crédito).
     *         Incluye el principal. El interés se maneja off-chain.
     */
    function repayCredit(uint256 amount)
        external onlyRole(MERCHANT_ROLE) nonReentrant
    {
        Merchant storage m = merchants[msg.sender];
        require(amount > 0, "MCP: amount = 0");
        require(amount <= m.creditUsed, "MCP: excede deuda actual");

        usdt.transferFrom(msg.sender, address(this), amount);
        m.creditUsed -= amount;
        poolBalance += amount;
        totalCreditOut -= amount;

        emit CreditRepaid(msg.sender, amount);
    }

    // ─────────────────────────────────────────────
    //  Rewards del comerciante
    // ─────────────────────────────────────────────

    /**
     * @notice Registrar un pago procesado por el comerciante y acumular reward.
     *         Llamado por PaymentProcessor cuando un usuario paga a este merchant.
     * @param merchant Dirección del comerciante
     * @param usdtAmount Monto del pago en USDT
     */
    function recordPaymentAndAccrueReward(address merchant, uint256 usdtAmount)
        external onlyRole(ADMIN_ROLE)
    {
        require(merchants[merchant].active, "MCP: comerciante inactivo");

        // Actualizar volumen
        merchants[merchant].totalVolumeProcessed += usdtAmount;

        // Calcular reward (% del pago)
        uint256 reward = (usdtAmount * rewardRatePerTx) / 10000;

        if (reward > 0 && poolBalance >= reward) {
            merchants[merchant].totalRewardsEarned += reward;
            poolBalance -= reward;
            totalRewardsPending += reward;
            emit RewardAccrued(merchant, reward, usdtAmount);
        }

        emit VolumeRecorded(merchant, usdtAmount);

        // Auto-upgrade de score por volumen
        _checkScoreUpgrade(merchant);
    }

    /**
     * @notice Comerciante retira sus rewards acumulados.
     *         Solo puede retirar rewards, NO el crédito.
     */
    function withdrawRewards() external onlyRole(MERCHANT_ROLE) nonReentrant {
        Merchant storage m = merchants[msg.sender];
        uint256 pending = m.totalRewardsEarned - m.rewardsPaid;
        require(pending > 0, "MCP: sin rewards pendientes");

        m.rewardsPaid += pending;
        totalRewardsPending -= pending;

        usdt.transfer(msg.sender, pending);

        emit RewardWithdrawn(msg.sender, pending);
    }

    /**
     * @notice Rewards disponibles para retirar del comerciante.
     */
    function pendingRewards(address merchant) external view returns (uint256) {
        Merchant storage m = merchants[merchant];
        return m.totalRewardsEarned - m.rewardsPaid;
    }

    /**
     * @notice Crédito disponible (cupo restante) del comerciante.
     */
    function availableCredit(address merchant) external view returns (uint256) {
        Merchant storage m = merchants[merchant];
        if (m.creditUsed >= m.creditLimit) return 0;
        return m.creditLimit - m.creditUsed;
    }

    // ─────────────────────────────────────────────
    //  Lógica interna: auto-upgrade de score
    // ─────────────────────────────────────────────

    /**
     * @dev Sube automáticamente el score si el volumen acumulado lo justifica.
     *      El admin puede siempre sobreescribir manualmente con updateCreditScore().
     *
     *      Umbrales de volumen acumulado:
     *        Score 2: $500 USDT procesados
     *        Score 3: $5,000 USDT procesados
     *        Score 4: $20,000 USDT procesados
     *        Score 5: manual solo (requiere KYC/revisión del admin)
     */
    function _checkScoreUpgrade(address merchant) internal {
        Merchant storage m = merchants[merchant];
        uint256 vol = m.totalVolumeProcessed;
        uint8 current = m.creditScore;

        uint8 newScore = current;
        if (current < 2 && vol >= 500e6)    newScore = 2;
        if (current < 3 && vol >= 5_000e6)  newScore = 3;
        if (current < 4 && vol >= 20_000e6) newScore = 4;
        // Score 5 es siempre manual

        if (newScore > current) {
            uint256 oldLimit = m.creditLimit;
            m.creditScore = newScore;
            m.creditLimit = scoreCreditCaps[newScore];
            emit CreditScoreUpdated(merchant, current, newScore);
            emit CreditLimitUpdated(merchant, oldLimit, m.creditLimit);
        }
    }

    // ─────────────────────────────────────────────
    //  Admin: configuración
    // ─────────────────────────────────────────────

    function setRewardRate(uint256 basisPoints) external onlyRole(ADMIN_ROLE) {
        require(basisPoints <= 500, "MCP: maximo 5% por tx");
        rewardRatePerTx = basisPoints;
    }

    function pause() external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    // ─────────────────────────────────────────────
    //  Vistas
    // ─────────────────────────────────────────────

    function getMerchant(address merchant) external view returns (Merchant memory) {
        return merchants[merchant];
    }

    function getMerchantCount() external view returns (uint256) {
        return merchantList.length;
    }

    function getPoolStats() external view returns (
        uint256 available,
        uint256 lent,
        uint256 rewardsPending
    ) {
        return (poolBalance, totalCreditOut, totalRewardsPending);
    }
}
