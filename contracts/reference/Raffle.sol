// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IRewardTicket {
    function burn(address from, uint256 amount) external;
}

/**
 * @title Raffle
 * @dev Cada N pagos a comercios se abre una rifa con 3 ganadores.
 *      Los usuarios entran quemando tickets (mas tickets = mas chance).
 *      Seleccion ponderada sin reemplazo: cada ganador se excluye antes del siguiente sorteo.
 *      El owner sortea con draw(). Los premios son fisicos.
 */
contract Raffle is Ownable {
    IRewardTicket public ticket;
    address public paymentProcessor;

    uint256 public txCount;
    uint256 public txThreshold = 5;
    uint256 public currentRound;
    bool    public isOpen;

    uint256 public constant MAX_WINNERS = 3;

    struct Round {
        string   prize;
        uint256  totalStaked;
        address[] participants;
        address[3] winners;
        uint256  winnersCount;   // cuantos ganadores se eligieron (min(3, participants))
        bool     drawn;
    }

    mapping(uint256 => Round)                       private _rounds;
    mapping(uint256 => mapping(address => uint256)) public  stakes;

    /* -----------------------------------------------------------------------
     *  EVENTS
     * ----------------------------------------------------------------------- */
    event RaffleOpened(uint256 indexed round, string prize);
    event TicketsStaked(uint256 indexed round, address indexed user, uint256 amount);
    event RaffleDrawn(uint256 indexed round, address[3] winners, uint256 winnersCount);
    event TransactionRecorded(uint256 indexed txCount);

    /* -----------------------------------------------------------------------
     *  CONSTRUCTOR
     * ----------------------------------------------------------------------- */
    constructor(address _ticket) Ownable(msg.sender) {
        ticket = IRewardTicket(_ticket);
    }

    /* -----------------------------------------------------------------------
     *  CONFIGURACION (owner)
     * ----------------------------------------------------------------------- */
    function setPaymentProcessor(address _processor) external onlyOwner {
        paymentProcessor = _processor;
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Raffle: threshold must be > 0");
        txThreshold = _threshold;
    }

    /* -----------------------------------------------------------------------
     *  REGISTRO DE PAGOS (llamado por PaymentProcessor)
     * ----------------------------------------------------------------------- */
    function recordTransaction() external {
        require(msg.sender == paymentProcessor, "Raffle: not authorized");
        txCount++;
        emit TransactionRecorded(txCount);

        if (txCount % txThreshold == 0 && !isOpen) {
            currentRound++;
            isOpen = true;
            _rounds[currentRound].prize = "3 Helados Coco";
            emit RaffleOpened(currentRound, "3 Helados Coco");
        }
    }

    /* -----------------------------------------------------------------------
     *  PARTICIPAR EN LA RIFA
     * ----------------------------------------------------------------------- */
    function enter(uint256 amount) external {
        require(isOpen, "Raffle: no hay rifa activa");
        require(amount >= 1, "Raffle: minimo 1 ticket");

        Round storage r = _rounds[currentRound];
        require(!r.drawn, "Raffle: ya fue sorteada");

        if (stakes[currentRound][msg.sender] == 0) {
            r.participants.push(msg.sender);
        }

        ticket.burn(msg.sender, amount);

        stakes[currentRound][msg.sender] += amount;
        r.totalStaked += amount;

        emit TicketsStaked(currentRound, msg.sender, amount);
    }

    /* -----------------------------------------------------------------------
     *  SORTEO — 3 ganadores ponderados sin reemplazo (owner)
     * ----------------------------------------------------------------------- */
    function draw() external onlyOwner {
        require(isOpen, "Raffle: no hay rifa activa");
        Round storage r = _rounds[currentRound];
        require(!r.drawn, "Raffle: ya fue sorteada");
        require(r.participants.length > 0, "Raffle: sin participantes");

        uint256 n = r.participants.length;

        // Copia temporal de stakes para poder excluir ganadores sin modificar el storage
        uint256[] memory tempStakes = new uint256[](n);
        uint256 tempTotal = r.totalStaked;
        for (uint256 i = 0; i < n; i++) {
            tempStakes[i] = stakes[currentRound][r.participants[i]];
        }

        // Elegir hasta 3 ganadores unicos
        uint256 numWinners = n < MAX_WINNERS ? n : MAX_WINNERS;

        for (uint256 w = 0; w < numWinners; w++) {
            uint256 seed = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                tempTotal,
                currentRound,
                w,
                r.participants.length
            )));

            uint256 target     = seed % tempTotal;
            uint256 cumulative = 0;

            for (uint256 i = 0; i < n; i++) {
                if (tempStakes[i] == 0) continue; // ya gano
                cumulative += tempStakes[i];
                if (cumulative > target) {
                    r.winners[w] = r.participants[i];
                    tempTotal   -= tempStakes[i];
                    tempStakes[i] = 0;
                    break;
                }
            }
        }

        r.winnersCount = numWinners;
        r.drawn  = true;
        isOpen   = false;

        emit RaffleDrawn(currentRound, r.winners, numWinners);
    }

    /* -----------------------------------------------------------------------
     *  VIEWS
     * ----------------------------------------------------------------------- */
    function getRaffleState() external view returns (
        uint256  _txCount,
        uint256  _txThreshold,
        uint256  _currentRound,
        bool     _isOpen,
        uint256  totalStaked,
        uint256  participantCount,
        address[3] memory winners,
        uint256  winnersCount,
        bool     drawn,
        string   memory prize
    ) {
        Round storage r = _rounds[currentRound];
        return (
            txCount,
            txThreshold,
            currentRound,
            isOpen,
            r.totalStaked,
            r.participants.length,
            r.winners,
            r.winnersCount,
            r.drawn,
            r.prize
        );
    }

    function myStake(address user) external view returns (uint256) {
        return stakes[currentRound][user];
    }
}
