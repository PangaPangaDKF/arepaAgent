// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MerchantRegistry is Ownable {
    struct Merchant {
        string name;
        address wallet;
        bool verified;
    }

    mapping(address => Merchant) public merchants;

    event MerchantRegistered(address indexed merchant, string name);
    event MerchantVerified(address indexed merchant);

    constructor() Ownable(msg.sender) {}

    function registerMerchant(string memory _name) external {
        require(bytes(merchants[msg.sender].name).length == 0, "Already registered");
        merchants[msg.sender] = Merchant({
            name:     _name,
            wallet:   msg.sender,
            verified: false
        });
        emit MerchantRegistered(msg.sender, _name);
    }

    function verifyMerchant(address _merchant) external onlyOwner {
        require(bytes(merchants[_merchant].name).length > 0, "Not registered");
        merchants[_merchant].verified = true;
        emit MerchantVerified(_merchant);
    }

    // Admin registra y verifica un merchant en un solo paso (útil para onboarding)
    function adminRegisterAndVerify(address _merchant, string memory _name) external onlyOwner {
        require(_merchant != address(0), "Invalid address");
        merchants[_merchant] = Merchant({ name: _name, wallet: _merchant, verified: true });
        emit MerchantRegistered(_merchant, _name);
        emit MerchantVerified(_merchant);
    }

    function isMerchant(address addr) external view returns (bool) {
        return merchants[addr].verified;
    }
}
