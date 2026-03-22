// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { InternetVoucher } from "src/InternetVoucher.sol";
import { PaymentProcessor } from "src/PaymentProcessor.sol";
import { RewardTicket }     from "src/RewardNFT.sol";

/**
 * @dev Despliega InternetVoucher y un nuevo PaymentProcessor v5 que lo integra.
 *      RewardTicket y Raffle existentes no cambian.
 *
 * Uso:
 *   source ../.env && PRIVATE_KEY=$PRIVATE_KEY forge script script/DeployInternetVoucher.s.sol \
 *     --rpc-url https://api.avax-test.network/ext/bc/C/rpc --broadcast
 */
contract DeployInternetVoucher is Script {
    // Contratos que NO cambian
    address constant REGISTRY     = 0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B;
    address constant MOCK_USDT    = 0xCfEfB29bD69C0af628A1D206c366133629011820;
    address constant REWARD_TICKET = 0x5430B7598ea098eB2E217bebda1406805f142aEf;
    address constant RAFFLE        = 0x3c25B5E7C32f258932071801Ea200BbDdd3A1CC0;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // 1. InternetVoucher
        InternetVoucher voucher = new InternetVoucher();

        // 2. PaymentProcessor v5
        PaymentProcessor processor = new PaymentProcessor(
            REGISTRY,
            MOCK_USDT,
            REWARD_TICKET,
            RAFFLE,
            address(voucher)
        );

        // 3. Autorizar el nuevo processor en RewardTicket existente
        RewardTicket(REWARD_TICKET).setPaymentProcessor(address(processor));

        // 4. Autorizar el nuevo processor en InternetVoucher
        voucher.setPaymentProcessor(address(processor));

        console.log("InternetVoucher  :", address(voucher));
        console.log("PaymentProcessor :", address(processor));

        vm.stopBroadcast();
    }
}
