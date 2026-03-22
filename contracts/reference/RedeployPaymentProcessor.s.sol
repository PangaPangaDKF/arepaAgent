// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { PaymentProcessor } from "src/PaymentProcessor.sol";
import { RewardTicket }     from "src/RewardNFT.sol";

/**
 * @dev Redesplega solo el PaymentProcessor con soporte para RewardTicket.
 *      Los demas contratos (registry, usdt, rewardTicket) ya existen en Fuji.
 *
 * Uso:
 *   forge script script/RedeployPaymentProcessor.s.sol \
 *     --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *     --broadcast --verify
 */
contract RedeployPaymentProcessor is Script {
    // Contratos ya existentes en Fuji — NO cambiar
    address constant REGISTRY      = 0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B;
    address constant MOCK_USDT     = 0xCfEfB29bD69C0af628A1D206c366133629011820;
    address constant REWARD_TICKET = 0x44c5a18FDBba53E71EDD652C0FCCB3cfCd586EF3;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // 1. Deploy nuevo PaymentProcessor con los 3 contratos existentes
        PaymentProcessor processor = new PaymentProcessor(
            REGISTRY,
            MOCK_USDT,
            REWARD_TICKET,
            address(0),
            address(0)
        );

        // 2. Apuntar RewardTicket al nuevo PaymentProcessor
        RewardTicket(REWARD_TICKET).setPaymentProcessor(address(processor));

        console.log("Nuevo PaymentProcessor:", address(processor));

        vm.stopBroadcast();
    }
}
