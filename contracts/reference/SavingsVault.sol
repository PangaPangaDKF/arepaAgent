// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SavingsVault — ArepaPay VAEM
 * @notice Usuarios depositan USDT y reciben sUSDT (savings USDT).
 *         El vault acumula yield de dos fuentes:
 *           1. Fee del protocolo (25% del fee total)
 *           2. Inyecciones manuales del admin (desde arbitraje VES)
 *         sUSDT crece en valor vs USDT con el tiempo.
 *         1 sUSDT siempre vale >= 1 USDT (nunca pierde).
 *
 * Modelo similar a: sDAI de MakerDAO, sUSDE de Ethena
 * Diferencia: el yield viene de arbitraje VES real, no de DeFi on-chain
 */
contract SavingsVault is ERC20, Ownable, ReentrancyGuard {
    IERC20 public immutable usdt;

    // Total de USDT en el vault (incluye yield acumulado)
    uint256 public totalAssets;

    // Historial de yield inyectado para transparencia
    uint256 public totalYieldInjected;
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    // Restricciones
    uint256 public minDeposit = 1e6;        // 1 USDT mínimo (6 decimales)
    uint256 public maxDeposit = 10_000e6;   // 10,000 USDT máximo por usuario
    bool    public depositsEnabled = true;

    event Deposited(address indexed user, uint256 usdtAmount, uint256 sUsdtMinted);
    event Withdrawn(address indexed user, uint256 sUsdtBurned, uint256 usdtAmount);
    event YieldInjected(address indexed source, uint256 amount, string reason);

    constructor(address _usdt) ERC20("ArepaPay Savings USDT", "sUSDT") Ownable(msg.sender) {
        usdt = IERC20(_usdt);
    }

    // ─────────────────────────────────────────────
    //  Vista: precio de 1 sUSDT en USDT
    // ─────────────────────────────────────────────

    /**
     * @notice Cuánto USDT vale 1 sUSDT actualmente.
     *         Arranca en 1.0 y solo sube con el yield.
     */
    function pricePerShare() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e6; // 1 USDT (6 decimales)
        return (totalAssets * 1e6) / supply;
    }

    /**
     * @notice Convierte USDT → sUSDT según el precio actual
     */
    function usdtToShares(uint256 usdtAmount) public view returns (uint256) {
        uint256 price = pricePerShare();
        return (usdtAmount * 1e6) / price;
    }

    /**
     * @notice Convierte sUSDT → USDT según el precio actual
     */
    function sharesToUsdt(uint256 shares) public view returns (uint256) {
        uint256 price = pricePerShare();
        return (shares * price) / 1e6;
    }

    // ─────────────────────────────────────────────
    //  Acciones del usuario
    // ─────────────────────────────────────────────

    /**
     * @notice Depositar USDT y recibir sUSDT.
     *         A mayor precio de sUSDT, menos sUSDT recibes (la proporción es justa).
     */
    function deposit(uint256 usdtAmount) external nonReentrant {
        require(depositsEnabled, "Vault: depositos pausados");
        require(usdtAmount >= minDeposit, "Vault: monto minimo no alcanzado");
        require(usdtAmount <= maxDeposit, "Vault: supera el maximo por deposito");

        uint256 shares = usdtToShares(usdtAmount);
        require(shares > 0, "Vault: shares calculadas = 0");

        usdt.transferFrom(msg.sender, address(this), usdtAmount);
        totalAssets += usdtAmount;
        totalDeposited += usdtAmount;

        _mint(msg.sender, shares);

        emit Deposited(msg.sender, usdtAmount, shares);
    }

    /**
     * @notice Retirar todo el sUSDT del caller y recibir USDT + yield.
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0, "Vault: shares = 0");
        require(balanceOf(msg.sender) >= shares, "Vault: saldo insuficiente");

        uint256 usdtAmount = sharesToUsdt(shares);
        require(usdtAmount > 0, "Vault: USDT calculado = 0");
        require(totalAssets >= usdtAmount, "Vault: liquidez insuficiente");

        _burn(msg.sender, shares);
        totalAssets -= usdtAmount;
        totalWithdrawn += usdtAmount;

        usdt.transfer(msg.sender, usdtAmount);

        emit Withdrawn(msg.sender, shares, usdtAmount);
    }

    /**
     * @notice Saldo en USDT actual del caller (incluyendo yield ganado).
     */
    function balanceInUsdt(address user) external view returns (uint256) {
        return sharesToUsdt(balanceOf(user));
    }

    // ─────────────────────────────────────────────
    //  Admin: inyección de yield
    // ─────────────────────────────────────────────

    /**
     * @notice Admin inyecta USDT al vault como yield.
     *         Esto sube el precio de sUSDT para todos los holders.
     *         Fuente 1: 25% del fee del protocolo (via RevenueDistributor)
     *         Fuente 2: % del arbitraje VES que el admin decide compartir
     * @param reason Descripción de la fuente del yield (para transparencia)
     */
    function injectYield(uint256 amount, string calldata reason) external onlyOwner {
        require(amount > 0, "Vault: amount = 0");
        usdt.transferFrom(msg.sender, address(this), amount);
        totalAssets += amount;
        totalYieldInjected += amount;
        emit YieldInjected(msg.sender, amount, reason);
    }

    /**
     * @notice El RevenueDistributor puede llamar esto también (cuando esté deployado).
     *         Se usa para distribuir automáticamente el 25% del fee del protocolo.
     */
    function receiveYield(uint256 amount) external {
        require(amount > 0, "Vault: amount = 0");
        usdt.transferFrom(msg.sender, address(this), amount);
        totalAssets += amount;
        totalYieldInjected += amount;
        emit YieldInjected(msg.sender, amount, "protocol_fee_distribution");
    }

    // ─────────────────────────────────────────────
    //  Admin: configuración
    // ─────────────────────────────────────────────

    function setMinDeposit(uint256 amount) external onlyOwner {
        minDeposit = amount;
    }

    function setMaxDeposit(uint256 amount) external onlyOwner {
        maxDeposit = amount;
    }

    function setDepositsEnabled(bool enabled) external onlyOwner {
        depositsEnabled = enabled;
    }

    /**
     * @notice Emergencia: el admin puede retirar USDT del vault.
     *         Solo si hay una emergencia real. Reduce totalAssets (baja sUSDT price).
     *         Usar con MUCHO cuidado — afecta la confianza de los holders.
     */
    function emergencyWithdraw(uint256 amount, address to) external onlyOwner {
        require(amount <= totalAssets, "Vault: excede activos");
        totalAssets -= amount;
        usdt.transfer(to, amount);
    }
}
