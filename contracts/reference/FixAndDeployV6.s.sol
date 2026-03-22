// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { PaymentProcessor } from "src/PaymentProcessor.sol";
import { RewardTicket }     from "src/RewardNFT.sol";
import { Raffle }           from "src/Raffle.sol";
import { InternetVoucher }  from "src/InternetVoucher.sol";

/**
 * @dev Fixes:
 *   1. PaymentProcessor v6 — sin ticket al comercio + require(from != to)
 *   2. Actualiza autorizacion en RewardTicket, Raffle e InternetVoucher
 *
 * Contratos que NO cambian: REGISTRY, MOCK_USDT, RAFFLE, REWARD_TICKET, INTERNET_VOUCHER
 */
contract FixAndDeployV6 is Script {
    address constant REGISTRY        = 0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B;
    address constant MOCK_USDT       = 0xCfEfB29bD69C0af628A1D206c366133629011820;
    address constant REWARD_TICKET   = 0x5430B7598ea098eB2E217bebda1406805f142aEf;
    address constant RAFFLE          = 0x3c25B5E7C32f258932071801Ea200BbDdd3A1CC0;
    address constant INTERNET_VOUCHER = 0xd72a6a47B342971380Fc02eF911103E09b47B8AD;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // 1. Deploy PaymentProcessor v6
        PaymentProcessor processor = new PaymentProcessor(
            REGISTRY,
            MOCK_USDT,
            REWARD_TICKET,
            RAFFLE,
            INTERNET_VOUCHER
        );

        // 2. Autorizar v6 en los 3 contratos de recompensas
        RewardTicket(REWARD_TICKET).setPaymentProcessor(address(processor));
        Raffle(RAFFLE).setPaymentProcessor(address(processor));         // FIX CRITICO
        InternetVoucher(INTERNET_VOUCHER).setPaymentProcessor(address(processor));

        console.log("PaymentProcessor v6:", address(processor));
        console.log("Raffle autorizado:  ", RAFFLE);
        console.log("RewardTicket:       ", REWARD_TICKET);
        console.log("InternetVoucher:    ", INTERNET_VOUCHER);

        vm.stopBroadcast();
    }
}
