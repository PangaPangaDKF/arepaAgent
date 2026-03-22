// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 }  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityManager
 * @dev Simula un pool de liquidez simple para USDT ↔︎ AREPA.
 *      No implementa swapping real, solo sirve para pruebas de integración.
 */
contract LiquidityManager is Ownable {
    IERC20 public usdt;
    IERC20 public arepa;

    // Simple mapping de "balances internos" del pool
    uint256 public usdtReserve;
    uint256 public arepaReserve;

    event LiquidityAdded(address indexed provider, uint256 usdtAmount, uint256 arepaAmount);
    event LiquidityRemoved(address indexed provider, uint256 usdtAmount, uint256 arepaAmount);

    constructor(address _usdt, address _arepa) Ownable(msg.sender) {
        usdt  = IERC20(_usdt);
        arepa = IERC20(_arepa);
    }

    /**
     * @dev Añade liquidez al pool. El provider transfiere ambos tokens al contrato.
     */
    function addLiquidity(uint256 _usdtAmount, uint256 _arepaAmount) external onlyOwner {
        require(_usdtAmount > 0 && _arepaAmount > 0, "LiquidityManager: amount zero");

        // Transferir los tokens al contrato
        require(usdt.transferFrom(msg.sender, address(this), _usdtAmount), "USDT transfer failed");
        require(arepa.transferFrom(msg.sender, address(this), _arepaAmount), "AREPA transfer failed");

        usdtReserve  += _usdtAmount;
        arepaReserve += _arepaAmount;

        emit LiquidityAdded(msg.sender, _usdtAmount, _arepaAmount);
    }

    /**
     * @dev Retira liquidez del pool (solo el owner en este entorno de pruebas).
     */
    function removeLiquidity(uint256 _usdtAmount, uint256 _arepaAmount) external onlyOwner {
        require(_usdtAmount <= usdtReserve && _arepaAmount <= arepaReserve, "Insufficient reserve");

        usdtReserve  -= _usdtAmount;
        arepaReserve -= _arepaAmount;

        require(usdt.transfer(msg.sender, _usdtAmount), "USDT withdraw failed");
        require(arepa.transfer(msg.sender, _arepaAmount), "AREPA withdraw failed");

        emit LiquidityRemoved(msg.sender, _usdtAmount, _arepaAmount);
    }

    /**
     * @dev Consulta los balances del pool.
     */
    function getReserves() external view returns (uint256 usdtAmt, uint256 arepaAmt) {
        return (usdtReserve, arepaReserve);
    }
}
