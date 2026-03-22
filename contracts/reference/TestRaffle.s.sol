// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPaymentProcessor {
    function payMerchant(address merchant, uint256 amount) external;
}

interface IRaffle {
    function getRaffleState() external view returns (
        uint256 txCount,
        uint256 txThreshold,
        uint256 currentRound,
        bool isOpen,
        uint256 totalStaked,
        uint256 participantCount,
        address[3] memory winners,
        uint256 winnersCount,
        bool drawn,
        string memory prize
    );
    function enter(uint256 amount) external;
    function myStake(address user) external view returns (uint256);
    function setThreshold(uint256 _threshold) external;
    function draw() external;
}

interface IRewardTicket {
    function balanceOf(address) external view returns (uint256);
}

/**
 * @title TestRaffle
 * @dev Script de prueba completo para la rifa con múltiples wallets.
 *
 *      PASO 1 — Bajar el threshold a 4 y hacer 4 pagos (abrir rifa):
 *        PRIVATE_KEY=0x... forge script script/TestRaffle.s.sol:TestRaffle \
 *          --sig "setupRaffle()" \
 *          --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *          --broadcast
 *
 *      PASO 2 — Wallet 1 entra a la rifa con 2 tickets:
 *        PRIVATE_KEY=0x<PK_WALLET1> forge script script/TestRaffle.s.sol:TestRaffle \
 *          --sig "enterRaffle(uint256)" 2 \
 *          --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *          --broadcast
 *
 *      PASO 2b — Wallet 2 y 3 también entran (correr con sus respectivos $PRIVATE_KEY):
 *        PRIVATE_KEY=0x<PK_WALLET2> forge script ... --sig "enterRaffle(uint256)" 1 ...
 *        PRIVATE_KEY=0x<PK_WALLET3> forge script ... --sig "enterRaffle(uint256)" 3 ...
 *
 *      PASO 3 — Owner sortea (3 ganadores ponderados):
 *        PRIVATE_KEY=0x<PK_OWNER> forge script script/TestRaffle.s.sol:TestRaffle \
 *          --sig "drawWinners()" \
 *          --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *          --broadcast
 */
contract TestRaffle is Script {

    // ── Contratos actuales en Fuji Testnet ────────────────────────────────────
    address constant MOCK_USDT          = 0xCfEfB29bD69C0af628A1D206c366133629011820;
    address constant PAYMENT_PROCESSOR  = 0xb10EE9c97Db6be098406618c2088eAC87e994483;
    address constant RAFFLE             = 0x3c25B5E7C32f258932071801Ea200BbDdd3A1CC0;
    address constant REWARD_TICKET      = 0x5430B7598ea098eB2E217bebda1406805f142aEf;

    // ── Comercios verificados ─────────────────────────────────────────────────
    address constant PANADERIA = 0x9bEDc23e74204Ab4507a377ab5B59A7B7265a6c5;
    address constant AGUA      = 0xc79D59461fC9deF5C725b2272174230cd88Cd621;
    address constant PERROS    = 0xeB484FaA415111198E2abcd79B286CAE7A4FfD8A;
    address constant BODEGA    = 0x07727f6710C01f2f075284Fc5FCCb05BaB3A48c2;

    uint256 constant AMOUNT = 1 * 10 ** 18; // 1 USDT por pago

    // ─────────────────────────────────────────────────────────────────────────
    // PASO 1: Owner baja threshold a 4 y hace 4 pagos para abrir la rifa
    // ─────────────────────────────────────────────────────────────────────────
    function setupRaffle() external {
        uint256 ownerKey = vm.envUint("PRIVATE_KEY");
        address owner    = vm.addr(ownerKey);

        _printState("ESTADO INICIAL", owner);

        vm.startBroadcast(ownerKey);

        // Bajar threshold a 4 para testing
        IRaffle(RAFFLE).setThreshold(4);
        console.log("Threshold bajado a 4");

        // Aprobar USDT
        IERC20(MOCK_USDT).approve(PAYMENT_PROCESSOR, 10 * 10 ** 18);

        // 4 pagos para abrir la rifa
        address[4] memory merchants = [PANADERIA, AGUA, PERROS, BODEGA];
        for (uint i = 0; i < 4; i++) {
            IPaymentProcessor(PAYMENT_PROCESSOR).payMerchant(merchants[i], AMOUNT);
            console.log("Pago", i + 1, "enviado");
        }

        vm.stopBroadcast();

        _printState("DESPUES DE 4 PAGOS", owner);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PASO 2: Una wallet entra a la rifa apostando N tickets
    // Ejecutar con cada wallet que quiera participar
    // ─────────────────────────────────────────────────────────────────────────
    function enterRaffle(uint256 numTickets) external {
        uint256 walletKey = vm.envUint("PRIVATE_KEY");
        address wallet    = vm.addr(walletKey);

        uint256 tickets = IRewardTicket(REWARD_TICKET).balanceOf(wallet);
        console.log("Wallet:", wallet);
        console.log("Tickets disponibles:", tickets);
        require(tickets >= numTickets, "No tienes suficientes tickets");

        vm.startBroadcast(walletKey);
        IRaffle(RAFFLE).enter(numTickets);
        vm.stopBroadcast();

        uint256 myStake = IRaffle(RAFFLE).myStake(wallet);
        (,,,,uint256 totalStaked, uint256 participants,,,, ) = IRaffle(RAFFLE).getRaffleState();
        console.log("Tickets apostados por ti:", myStake);
        console.log("Total en juego:", totalStaked);
        console.log("Total participantes:", participants);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PASO 3: Owner sortea — elige hasta 3 ganadores ponderados
    // ─────────────────────────────────────────────────────────────────────────
    function drawWinners() external {
        uint256 ownerKey = vm.envUint("PRIVATE_KEY");

        (,,,, uint256 totalStaked, uint256 participants,,,, string memory prize) =
            IRaffle(RAFFLE).getRaffleState();

        console.log("Sorteando...");
        console.log("Participantes:", participants);
        console.log("Tickets en juego:", totalStaked);
        console.log("Premio:", prize);

        vm.startBroadcast(ownerKey);
        IRaffle(RAFFLE).draw();
        vm.stopBroadcast();

        (,,uint256 round,,,, address[3] memory winners, uint256 winnersCount,,) =
            IRaffle(RAFFLE).getRaffleState();

        console.log("=== GANADORES RONDA", round, "===");
        for (uint i = 0; i < winnersCount; i++) {
            console.log(i == 0 ? "Ganador 1 (Oro):" : i == 1 ? "Ganador 2 (Plata):" : "Ganador 3 (Bronce):");
            console.logAddress(winners[i]);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helper: imprime el estado actual de la rifa
    // ─────────────────────────────────────────────────────────────────────────
    function _printState(string memory label, address wallet) internal view {
        (uint256 txCount, uint256 threshold, uint256 round, bool isOpen, uint256 totalStaked,
         uint256 participants,,, bool drawn, string memory prize) = IRaffle(RAFFLE).getRaffleState();

        uint256 tickets = IRewardTicket(REWARD_TICKET).balanceOf(wallet);
        uint256 usdt    = IERC20(MOCK_USDT).balanceOf(wallet);

        console.log(string.concat("--- ", label, " ---"));
        console.log("Pagos acumulados:", txCount);
        console.log("Threshold:", threshold);
        console.log("Ronda:", round);
        console.log("Rifa abierta:", isOpen);
        console.log("Premio:", prize);
        console.log("Participantes:", participants);
        console.log("Tickets en juego:", totalStaked);
        console.log("Sorteada:", drawn);
        console.log("Tu USDT:", usdt / 1e18);
        console.log("Tus tickets:", tickets);
    }
}
