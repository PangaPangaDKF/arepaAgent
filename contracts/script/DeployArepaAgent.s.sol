// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ArepaAgent.sol";

/**
 * @notice Deploy ArepaAgent to ArepaPay L1 (Chain ID 13370)
 *
 * Usage:
 *   forge script script/DeployArepaAgent.s.sol \
 *     --rpc-url http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast
 */
contract DeployArepaAgent is Script {

    // ArepaPay L1 contract addresses (Chain ID 13370, Deploy #4)
    // ArepaPay L1 addresses — fresh deploy on restarted L1
    address constant MOCK_USDT         = 0x29D720D6b5837f2b9d66834246635a4d8BC00d18;
    address constant PAYMENT_PROCESSOR = 0xc09b059534D779f500B94f0DdC677765eEb5674b;

    // Daily budget: 50 USDT (6 decimals)
    uint256 constant INITIAL_BUDGET = 50 * 1e6;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("=== ArepaAgent Deploy ===");
        console.log("Chain ID:          ", block.chainid);
        console.log("Deployer:          ", deployer);
        console.log("USDT:              ", MOCK_USDT);
        console.log("PaymentProcessor:  ", PAYMENT_PROCESSOR);
        console.log("Initial budget:    ", INITIAL_BUDGET / 1e6, "USDT");

        vm.startBroadcast(deployerKey);

        ArepaAgent agent = new ArepaAgent(
            MOCK_USDT,
            PAYMENT_PROCESSOR,
            deployer,          // owner = deployer
            INITIAL_BUDGET
        );

        // Register deployer as payment validator (agent can self-validate for MVP)
        agent.addPaymentValidator(deployer);

        console.log("\n=== DEPLOYED ===");
        console.log("ArepaAgent:        ", address(agent));
        console.log("Owner:             ", agent.owner());
        console.log("Daily budget:      ", agent.dailyBudget() / 1e6, "USDT");
        console.log("Autonomous mode:   ", agent.autonomousMode());

        vm.stopBroadcast();
    }
}
