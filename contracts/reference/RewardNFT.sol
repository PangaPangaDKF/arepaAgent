// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RewardTicket {
    /* -----------------------------------------------------------------------
     *  STORAGE
     * ----------------------------------------------------------------------- */
    mapping(address => uint256) private _balances;

    address public paymentProcessor;
    address public raffle;       // contrato de rifas autorizado a quemar tickets
    address public owner;

    /* -----------------------------------------------------------------------
     *  EVENTS
     * ----------------------------------------------------------------------- */
    event TicketMinted(address indexed to);
    event TicketBurned(address indexed from, uint256 amount);
    event TicketTransferred(address indexed from, address indexed to, uint256 amount);
    event PaymentProcessorSet(address indexed processor);
    event RaffleSet(address indexed raffle);

    /* -----------------------------------------------------------------------
     *  MODIFIERS
     * ----------------------------------------------------------------------- */
    modifier onlyOwner() {
        require(msg.sender == owner, "RewardTicket: not owner");
        _;
    }

    modifier onlyPaymentProcessor() {
        require(msg.sender == paymentProcessor, "RewardTicket: caller not processor");
        _;
    }

    /* -----------------------------------------------------------------------
     *  CONSTRUCTOR
     * ----------------------------------------------------------------------- */
    constructor() {
        owner = msg.sender;
    }

    /* -----------------------------------------------------------------------
     *  EXTERNAL / PUBLIC FUNCTIONS
     * ----------------------------------------------------------------------- */

    function setPaymentProcessor(address _processor) external onlyOwner {
        require(_processor != address(0), "RewardTicket: zero address");
        paymentProcessor = _processor;
        emit PaymentProcessorSet(_processor);
    }

    function setRaffle(address _raffle) external onlyOwner {
        require(_raffle != address(0), "RewardTicket: zero address");
        raffle = _raffle;
        emit RaffleSet(_raffle);
    }

    function mint(address to) external onlyPaymentProcessor {
        require(to != address(0), "RewardTicket: mint to zero");
        _balances[to] += 1;
        emit TicketMinted(to);
    }

    /// @dev Transfiere tickets entre wallets — cualquier holder puede llamarlo.
    function transfer(address to, uint256 amount) external {
        require(to != address(0), "RewardTicket: zero address");
        require(_balances[msg.sender] >= amount, "RewardTicket: insufficient tickets");
        unchecked {
            _balances[msg.sender] -= amount;
            _balances[to]         += amount;
        }
        emit TicketTransferred(msg.sender, to, amount);
    }

    /// @dev Quema tickets. Autorizado: el propio holder, paymentProcessor o el contrato raffle.
    function burn(address from, uint256 amount) external {
        require(from != address(0), "RewardTicket: burn from zero");
        require(_balances[from] >= amount, "RewardTicket: insufficient tickets");

        bool isAuthorized = (msg.sender == from)
            || (msg.sender == paymentProcessor)
            || (msg.sender == raffle);
        require(isAuthorized, "RewardTicket: not authorized");

        unchecked {
            _balances[from] -= amount;
        }
        emit TicketBurned(from, amount);
    }

    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "RewardTicket: zero address");
        return _balances[account];
    }
}
