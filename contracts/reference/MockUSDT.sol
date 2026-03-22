// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 }   from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDT
 * @dev ERC20 simple que simula USDT en la subnet local.
 *      El deployer recibe todo el suministro inicial.
 */
contract MockUSDT is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 6; // 1M USDT (6 decimales como USDT real)

    constructor() ERC20("Mock USDT", "USDT") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // USDT real usa 6 decimales
    function decimals() public pure override returns (uint8) { return 6; }

    /**
     * @dev Permite al owner “mintear” tokens para pruebas.
     */
    function faucet(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
