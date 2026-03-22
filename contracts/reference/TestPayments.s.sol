// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPaymentProcessor {
    function payMerchant(address merchant, uint256 amount) external;
}

interface IRaffle {
    function getRaffleState() external view returns (
        uint256 txCount, uint256 txThreshold, uint256 currentRound,
        bool isOpen, uint256 totalStaked, uint256 participantCount,
        address winner, bool drawn, string memory prize
    );
    function enter(uint256 amount) external;
    function myStake(address user) external view returns (uint256);
}

interface IRewardTicket {
    function balanceOf(address) external view returns (uint256);
}

/**
 * @dev Script de testing: hace 10 pagos a comercios para activar la rifa,
 *      luego entra a la rifa con los tickets ganados.
 *
 * Uso:
 *   PRIVATE_KEY=0x... forge script script/TestPayments.s.sol \
 *     --rpc-url https://api.avax-test.network/ext/bc/C/rpc \
 *     --broadcast
 */
contract TestPayments is Script {
    address constant MOCK_USDT         = 0xCfEfB29bD69C0af628A1D206c366133629011820;
    address constant PAYMENT_PROCESSOR = 0x04aBE4A493F38cd729d9c30b805447e60476A30b;
    address constant RAFFLE            = 0x4f4C87EF9b1260e87b0DA61f8A19861964ee0bF5;
    address constant REWARD_TICKET     = 0x187a3Ced80eDC2c576376f85568C6f2F751D7e17;

    // Comercios verificados
    address constant PANADERIA = 0x9bEDc23e74204Ab4507a377ab5B59A7B7265a6c5;
    address constant AGUA      = 0xc79D59461fC9deF5C725b2272174230cd88Cd621;
    address constant PERROS    = 0xeB484FaA415111198E2abcd79B286CAE7A4FfD8A;
    address constant BODEGA    = 0x07727f6710C01f2f075284Fc5FCCb05BaB3A48c2;

    uint256 constant AMOUNT = 1 * 10 ** 18; // 1 USDT por pago

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        // Estado inicial
        {
            (uint256 txCount,,,,,,,,) = IRaffle(RAFFLE).getRaffleState();
            uint256 tickets = IRewardTicket(REWARD_TICKET).balanceOf(deployer);
            uint256 balance = IERC20(MOCK_USDT).balanceOf(deployer);
            console.log("--- ESTADO INICIAL ---");
            console.log("Deployer USDT:", balance / 1e18);
            console.log("Tickets actuales:", tickets);
            console.log("Pagos registrados en raffle:", txCount);
        }

        vm.startBroadcast(deployerKey);

        // Aprobar 100 USDT al PaymentProcessor (suficiente para 10 pagos de 1 USDT c/u)
        IERC20(MOCK_USDT).approve(PAYMENT_PROCESSOR, 100 * 10 ** 18);

        // 10 pagos rotando entre los 4 comercios
        address[4] memory merchants = [PANADERIA, AGUA, PERROS, BODEGA];
        for (uint i = 0; i < 10; i++) {
            IPaymentProcessor(PAYMENT_PROCESSOR).payMerchant(merchants[i % 4], AMOUNT);
            console.log("Pago", i + 1, "a comercio", i % 4);
        }

        vm.stopBroadcast();

        // Estado despues de los pagos
        {
            (uint256 txCount,, uint256 currentRound, bool isOpen,,,,, string memory prize) =
                IRaffle(RAFFLE).getRaffleState();
            uint256 tickets = IRewardTicket(REWARD_TICKET).balanceOf(deployer);
            console.log("--- DESPUES DE 10 PAGOS ---");
            console.log("Pagos totales:", txCount);
            console.log("Ronda actual:", currentRound);
            console.log("Rifa abierta?", isOpen);
            console.log("Premio:", prize);
            console.log("Tickets del deployer:", tickets);
        }

        // Si la rifa esta abierta, entramos con 2 tickets
        (,,, bool open,,,,, ) = IRaffle(RAFFLE).getRaffleState();
        if (open) {
            console.log("Entrando a la rifa con 2 tickets...");
            vm.startBroadcast(deployerKey);
            IRaffle(RAFFLE).enter(2);
            vm.stopBroadcast();

            (,,,, uint256 totalStaked, uint256 participants,,,) = IRaffle(RAFFLE).getRaffleState();
            uint256 myStake = IRaffle(RAFFLE).myStake(deployer);
            console.log("Tickets en juego:", totalStaked);
            console.log("Participantes:", participants);
            console.log("Mis tickets apostados:", myStake);
        }
    }
}
