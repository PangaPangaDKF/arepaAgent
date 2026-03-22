// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { MerchantRegistry } from "src/MerchantRegistry.sol";
import { MockUSDT }         from "src/MockUSDT.sol";

/**
 * @title SetupL1
 * @notice Registra merchants de prueba y distribuye USDT para testing.
 *
 * Uso:
 *   forge script script/SetupL1.s.sol \
 *     --rpc-url http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc \
 *     --private-key 0x0faccdcb96ce0d00d7f5135fe4a82fd0d891c096428fd00b6212ef4c9231e1e2 \
 *     --broadcast -vv
 */
contract SetupL1 is Script {
    address constant REGISTRY  = 0xd9c61D113720D5EFe38f159c248F2D05cc5a9d69;
    address constant MOCK_USDT = 0x49FCa1a7E942bd8B76781731df4b13E730AEa8A0;

    address constant PANADERIA = 0x9bEDc23e74204Ab4507a377ab5B59A7B7265a6c5;
    address constant AGUA      = 0xc79D59461fC9deF5C725b2272174230cd88Cd621;
    address constant PERROS    = 0xeB484FaA415111198E2abcd79B286CAE7A4FfD8A;
    address constant BODEGA    = 0x07727f6710C01f2f075284Fc5FCCb05BaB3A48c2;

    // Wallet del usuario para testing (el deployer)
    address constant DEPLOYER  = 0x0D1F1B9409FF22E65974784D91D65f5f02d24741;

    uint256 constant TEST_USDT = 1_000 * 1e6; // 1,000 USDT por wallet

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MerchantRegistry registry = MerchantRegistry(REGISTRY);
        MockUSDT usdt = MockUSDT(MOCK_USDT);

        // Registrar y verificar merchants en un paso
        registry.adminRegisterAndVerify(PANADERIA, "Panaderia El Arepazo");
        registry.adminRegisterAndVerify(AGUA,      "Botellones El Mono");
        registry.adminRegisterAndVerify(PERROS,    "Perros Juancho");
        registry.adminRegisterAndVerify(BODEGA,    "La Bodega");
        console.log("4 merchants registrados y verificados");

        // USDT a cada merchant (para simular que tienen saldo si toca hacer demo inverso)
        usdt.faucet(PANADERIA, TEST_USDT);
        usdt.faucet(AGUA,      TEST_USDT);
        usdt.faucet(PERROS,    TEST_USDT);
        usdt.faucet(BODEGA,    TEST_USDT);
        console.log("1,000 USDT enviados a cada merchant");

        // USDT extra al deployer para tener suficiente para pagos de prueba
        usdt.faucet(DEPLOYER, 10_000 * 1e6); // +10,000 USDT
        console.log("10,000 USDT adicionales al deployer");

        vm.stopBroadcast();

        console.log("=== SETUP COMPLETO ===");
        console.log("Listo para probar pagos en http://localhost:5174");
    }
}
