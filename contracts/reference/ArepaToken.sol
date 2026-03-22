// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ArepaToken (AREPA)
 * @dev ERC20 simple que sirve como token de gas para la sub‑red.
 */
contract ArepaToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18; // 1 M AREPA

    constructor() ERC20("Arepa Token", "AREPA") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
