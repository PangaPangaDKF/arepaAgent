// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { MockUSDT }           from "src/MockUSDT.sol";
import { MerchantRegistry }   from "src/MerchantRegistry.sol";
import { RewardTicket }       from "src/RewardNFT.sol";
import { Raffle }             from "src/Raffle.sol";
import { InternetVoucher }    from "src/InternetVoucher.sol";
import { PaymentProcessor }   from "src/PaymentProcessor.sol";
import { SavingsVault }       from "src/SavingsVault.sol";
import { MerchantCreditPool } from "src/MerchantCreditPool.sol";
import { RevenueDistributor } from "src/RevenueDistributor.sol";
import { ArepaHub }          from "src/ArepaHub.sol";
import { OTCMarket }         from "src/OTCMarket.sol";

/**
 * @title DeployL1
 * @notice Deploy completo de ArepaPay en la L1 local (Chain ID 13370)
 *
 * Uso:
 *   forge script script/DeployL1.s.sol \
 *     --rpc-url http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc \
 *     --private-key 0faccdcb96ce0d00d7f5135fe4a82fd0d891c096428fd00b6212ef4c9231e1e2 \
 *     --broadcast -vvv
 */
contract DeployL1 is Script {
    // Deployer = owner de todos los contratos
    address constant DEPLOYER = 0x0D1F1B9409FF22E65974784D91D65f5f02d24741;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // ── 1. USDT (6 decimales, 1M supply al deployer) ──────────────────────
        MockUSDT usdt = new MockUSDT();
        console.log("MockUSDT:           ", address(usdt));

        // ── 2. MerchantRegistry ───────────────────────────────────────────────
        MerchantRegistry registry = new MerchantRegistry();
        console.log("MerchantRegistry:   ", address(registry));

        // ── 3. RewardTicket (NFT ticket de rifa) ──────────────────────────────
        RewardTicket ticket = new RewardTicket();
        console.log("RewardTicket:       ", address(ticket));

        // ── 4. Raffle ─────────────────────────────────────────────────────────
        Raffle raffle = new Raffle(address(ticket));
        console.log("Raffle:             ", address(raffle));

        // ── 5. InternetVoucher ────────────────────────────────────────────────
        InternetVoucher voucher = new InternetVoucher();
        console.log("InternetVoucher:    ", address(voucher));

        // ── 6. PaymentProcessor ───────────────────────────────────────────────
        PaymentProcessor processor = new PaymentProcessor(
            address(registry),
            address(usdt),
            address(ticket),
            address(raffle),
            address(voucher)
        );
        console.log("PaymentProcessor:   ", address(processor));

        // ── 7. SavingsVault (sUSDT) ───────────────────────────────────────────
        SavingsVault vault = new SavingsVault(address(usdt));
        console.log("SavingsVault:       ", address(vault));

        // ── 8. MerchantCreditPool ─────────────────────────────────────────────
        MerchantCreditPool pool = new MerchantCreditPool(address(usdt));
        console.log("MerchantCreditPool: ", address(pool));

        // ── 9. RevenueDistributor (VAEM) ──────────────────────────────────────
        //    datTreasury y adminReserve = deployer en testnet local
        RevenueDistributor revenue = new RevenueDistributor(
            address(usdt),
            DEPLOYER, // datTreasury
            DEPLOYER  // adminReserve
        );
        console.log("RevenueDistributor: ", address(revenue));

        // ── 10. ArepaHub ──────────────────────────────────────────────────────
        // bcvRateCents = 4200000 → 42.000 Bs por USDT (tasa inicial ejemplo)
        // adminMarginBps = 200 → 2% sobre BCV (admin gana 2% vendiendo USDT a merchants)
        ArepaHub hub = new ArepaHub(address(usdt), 4_200_000, 200);
        console.log("ArepaHub:           ", address(hub));

        // ── 11. OTCMarket ─────────────────────────────────────────────────────
        OTCMarket otc = new OTCMarket(address(usdt));
        console.log("OTCMarket:          ", address(otc));

        // ── 12. Wiring ────────────────────────────────────────────────────────
        // Conectar ticket con el processor (solo processor puede mintear)
        ticket.setPaymentProcessor(address(processor));

        // Conectar raffle con el processor (para recordTransaction)
        raffle.setPaymentProcessor(address(processor));

        // Conectar voucher con el processor (para mint de minutos)
        voucher.setPaymentProcessor(address(processor));

        // Conectar RevenueDistributor con vault y pool
        revenue.setDestinations(address(vault), address(pool));

        // ─────────────────────────────────────────────────────────────────────

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOY COMPLETO EN L1 ===");
        console.log("Chain ID: 13370");
        console.log("Deployer:", DEPLOYER);
        console.log("");
        console.log("Copiar en frontend/src/config/network.js:");
        console.log("  usdt:              ", address(usdt));
        console.log("  merchantRegistry:  ", address(registry));
        console.log("  rewardTicket:      ", address(ticket));
        console.log("  raffle:            ", address(raffle));
        console.log("  internetVoucher:   ", address(voucher));
        console.log("  paymentProcessor:  ", address(processor));
        console.log("  savingsVault:      ", address(vault));
        console.log("  merchantCreditPool:", address(pool));
        console.log("  revenueDistributor:", address(revenue));
        console.log("  arepaHub:          ", address(hub));
        console.log("  otcMarket:         ", address(otc));
    }
}
