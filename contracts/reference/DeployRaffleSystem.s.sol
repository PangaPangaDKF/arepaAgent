// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { PaymentProcessor } from "src/PaymentProcessor.sol";
import { RewardTicket }     from "src/RewardNFT.sol";
import { Raffle }           from "src/Raffle.sol";

/**
 * @dev Despliega el sistema completo de rifas:
 *   1. RewardTicket v2 (con transfer + raffle autorizado)
 *   2. Raffle v1 (contador de txns, entrada ponderada, sorteo)
 *   3. PaymentProcessor v3 (mintea tickets + registra en raffle)
 *   4. Configura todas las referencias entre contratos
 *
 * Uso:
 *   PRIVATE_KEY=0x... forge script script/DeployRaffleSystem.s.sol \
 *     --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *     --broadcast
 */
contract DeployRaffleSystem is Script {
    // Contratos que NO cambian
    address constant REGISTRY  = 0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B;
    address constant MOCK_USDT = 0xCfEfB29bD69C0af628A1D206c366133629011820;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // 1. Nuevo RewardTicket (con transfer + setRaffle)
        RewardTicket ticket = new RewardTicket();

        // 2. Contrato Raffle
        Raffle raffleContract = new Raffle(address(ticket));

        // 3. Nuevo PaymentProcessor (apunta a nuevo ticket + raffle)
        PaymentProcessor processor = new PaymentProcessor(
            REGISTRY,
            MOCK_USDT,
            address(ticket),
            address(raffleContract),
            address(0)
        );

        // 4. Configurar RewardTicket
        ticket.setPaymentProcessor(address(processor));
        ticket.setRaffle(address(raffleContract));

        // 5. Configurar Raffle
        raffleContract.setPaymentProcessor(address(processor));

        console.log("RewardTicket v2 :", address(ticket));
        console.log("Raffle          :", address(raffleContract));
        console.log("PaymentProcessor:", address(processor));

        vm.stopBroadcast();
    }
}
