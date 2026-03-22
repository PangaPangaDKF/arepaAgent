// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Script }           from "forge-std/Script.sol";
import { ArepaToken }       from "src/ArepaToken.sol";
import { MockUSDT }         from "src/MockUSDT.sol";
import { MerchantRegistry } from "src/MerchantRegistry.sol";
import { PaymentProcessor } from "src/PaymentProcessor.sol";
import { LiquidityManager } from "src/LiquidityManager.sol";
import { RewardTicket }     from "src/RewardNFT.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ArepaToken       arepa    = new ArepaToken();
        MockUSDT         usdt     = new MockUSDT();
        MerchantRegistry registry = new MerchantRegistry();
        RewardTicket     ticket   = new RewardTicket();

        PaymentProcessor processor = new PaymentProcessor(address(registry), address(usdt), address(ticket), address(0), address(0));
        new LiquidityManager(address(usdt), address(arepa));

        // Conectar RewardTicket con PaymentProcessor
        ticket.setPaymentProcessor(address(processor));

        vm.stopBroadcast();
    }
}
