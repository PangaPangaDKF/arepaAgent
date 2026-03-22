// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ArepaAgent
 * @notice ERC-8004 Autonomous AI Agent with x402 Payment Protocol Integration
 * @dev Adapted for ArepaPay L1 (Chain ID 13370):
 *      - No ERC-4337 dependency (no EntryPoint on L1)
 *      - USDT uses 6 decimals (real USDT standard)
 *      - Wired to ArepaPay L1 PaymentProcessor
 *
 * HACKATHON TRACK 4: Autonomous AI agent using x402 HTTP payment protocol
 * on a custom Avalanche L1, unlocking real-world services without human intervention.
 */
contract ArepaAgent is Ownable {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event X402PaymentExecuted(
        address indexed service,
        uint256 amount,
        string resource,
        bytes32 indexed paymentHash,
        address indexed paidBy
    );

    event BudgetUpdated(uint256 newDailyBudget, uint256 spentToday);
    event AutonomousModeSet(bool enabled);
    event ValidatorUpdated(address indexed validator, bool approved);
    event EmergencyPause(bool paused);
    event LiquidityInjected(address indexed from, uint256 amount);

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    /// @notice ERC-8004 interface identifier
    bytes4 public constant ERC8004_INTERFACE_ID = 0x80048004;

    // =========================================================================
    // IMMUTABLES
    // =========================================================================

    /// @notice USDT token on ArepaPay L1 (6 decimals)
    address public immutable USDT_TOKEN;

    /// @notice ArepaPay PaymentProcessor on L1
    address public immutable PAYMENT_PROCESSOR;

    // =========================================================================
    // STATE
    // =========================================================================

    /// @notice Daily spending limit in USDT (6 decimals)
    uint256 public dailyBudget;

    /// @notice Amount spent today (resets at UTC midnight)
    uint256 public spentToday;

    /// @notice Timestamp of last daily reset
    uint256 public lastResetDay;

    /// @notice Whether the agent operates without human confirmation
    bool public autonomousMode;

    /// @notice Whether all operations are paused
    bool public paused;

    /// @notice Addresses authorized to submit x402 payment requests
    mapping(address => bool) public paymentValidators;

    /// @notice Anti-replay: nonces that have been consumed
    mapping(uint256 => bool) public usedNonces;

    /// @notice On-chain payment history
    struct PaymentRecord {
        address service;        // Service or merchant that received payment
        uint256 amount;         // USDT amount (6 decimals)
        uint256 timestamp;
        string resource;        // API endpoint or resource description
        bool success;
    }
    PaymentRecord[] public paymentHistory;

    // =========================================================================
    // MODIFIERS
    // =========================================================================

    modifier whenNotPaused() {
        require(!paused, "ArepaAgent: paused");
        _;
    }

    modifier onlyValidator() {
        require(
            paymentValidators[msg.sender] || msg.sender == owner(),
            "ArepaAgent: not authorized validator"
        );
        _;
    }

    modifier withinBudget(uint256 amount) {
        _checkAndResetBudget();
        require(spentToday + amount <= dailyBudget, "ArepaAgent: daily budget exceeded");
        _;
    }

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    /**
     * @param usdtToken      MockUSDT address on ArepaPay L1
     * @param paymentProcessor PaymentProcessor address on ArepaPay L1
     * @param initialOwner   Agent owner (controls budget and validators)
     * @param initialBudget  Daily budget in USDT (6 decimals, e.g. 50e6 = 50 USDT)
     */
    constructor(
        address usdtToken,
        address paymentProcessor,
        address initialOwner,
        uint256 initialBudget
    ) Ownable(initialOwner) {
        require(usdtToken != address(0), "Invalid USDT");
        require(paymentProcessor != address(0), "Invalid PaymentProcessor");

        USDT_TOKEN = usdtToken;
        PAYMENT_PROCESSOR = paymentProcessor;
        dailyBudget = initialBudget;
        lastResetDay = block.timestamp / 1 days;
        autonomousMode = true; // Start in autonomous mode
    }

    // =========================================================================
    // ERC-8004 — AUTONOMOUS EXECUTION
    // =========================================================================

    /**
     * @notice Execute an arbitrary call on behalf of the agent (ERC-8004)
     * @dev Used by the AI agent to call any contract (e.g. ArepaHub, OTCMarket)
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused onlyValidator returns (bool success, bytes memory returnData) {
        require(target != address(0), "Invalid target");
        (success, returnData) = target.call{value: value}(data);
        require(success, "ArepaAgent: execution failed");
    }

    // =========================================================================
    // X402 PAYMENT PROTOCOL
    // =========================================================================

    /**
     * @notice Process an x402 payment for API access
     * @dev Called by the TypeScript agent after receiving HTTP 402 response.
     *      Verifies the validator's signature, checks budget, transfers USDT,
     *      and records the payment on-chain.
     *
     * @param service    Address receiving the USDT (merchant or service wallet)
     * @param amount     USDT amount in 6 decimals (e.g. 100000 = 0.10 USDT)
     * @param resource   Resource being unlocked (e.g. "/api/bcv-rate")
     * @param signature  EIP-191 signature from authorized validator
     * @param nonce      Unique nonce to prevent replay attacks
     */
    function processX402Payment(
        address service,
        uint256 amount,
        string calldata resource,
        bytes calldata signature,
        uint256 nonce
    )
        external
        whenNotPaused
        withinBudget(amount)
        onlyValidator
    {
        require(!usedNonces[nonce], "ArepaAgent: nonce already used");
        require(service != address(0), "Invalid service address");
        require(amount > 0, "Amount must be > 0");

        // Mark nonce as used (anti-replay)
        usedNonces[nonce] = true;

        // Verify signature from an authorized validator
        bytes32 messageHash = keccak256(
            abi.encodePacked(service, amount, resource, nonce)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ethSignedHash.recover(signature);
        require(paymentValidators[signer] || signer == owner(), "ArepaAgent: invalid signature");

        // Transfer USDT to service
        IERC20(USDT_TOKEN).safeTransfer(service, amount);

        // Track spending
        spentToday += amount;

        // Record on-chain
        bytes32 paymentHash = keccak256(abi.encodePacked(service, amount, nonce, block.timestamp));
        paymentHistory.push(PaymentRecord({
            service: service,
            amount: amount,
            timestamp: block.timestamp,
            resource: resource,
            success: true
        }));

        emit X402PaymentExecuted(service, amount, resource, paymentHash, msg.sender);
    }

    /**
     * @notice Simpler x402 payment — no signature required, owner/validator direct call
     * @dev Used for MVP demo where agent is its own validator
     */
    function processX402PaymentDirect(
        address service,
        uint256 amount,
        string calldata resource
    )
        external
        whenNotPaused
        withinBudget(amount)
        onlyValidator
    {
        require(service != address(0), "Invalid service");
        require(amount > 0, "Amount must be > 0");

        IERC20(USDT_TOKEN).safeTransfer(service, amount);
        spentToday += amount;

        bytes32 paymentHash = keccak256(abi.encodePacked(service, amount, block.timestamp));
        paymentHistory.push(PaymentRecord({
            service: service,
            amount: amount,
            timestamp: block.timestamp,
            resource: resource,
            success: true
        }));

        emit X402PaymentExecuted(service, amount, resource, paymentHash, msg.sender);
    }

    // =========================================================================
    // BUDGET MANAGEMENT
    // =========================================================================

    function setDailyBudget(uint256 newBudget) external onlyOwner {
        dailyBudget = newBudget;
        emit BudgetUpdated(newBudget, spentToday);
    }

    function getRemainingBudget() external view returns (uint256) {
        return dailyBudget > spentToday ? dailyBudget - spentToday : 0;
    }

    function isBudgetResetNeeded() external view returns (bool) {
        return block.timestamp / 1 days > lastResetDay;
    }

    // =========================================================================
    // AUTONOMOUS MODE & VALIDATORS
    // =========================================================================

    function setAutonomousMode(bool enabled) external onlyOwner {
        autonomousMode = enabled;
        emit AutonomousModeSet(enabled);
    }

    function addPaymentValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid address");
        paymentValidators[validator] = true;
        emit ValidatorUpdated(validator, true);
    }

    function removePaymentValidator(address validator) external onlyOwner {
        paymentValidators[validator] = false;
        emit ValidatorUpdated(validator, false);
    }

    // =========================================================================
    // EMERGENCY CONTROLS
    // =========================================================================

    function emergencyPause() external onlyOwner {
        paused = true;
        emit EmergencyPause(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit EmergencyPause(false);
    }

    // =========================================================================
    // FUNDING & WITHDRAWAL
    // =========================================================================

    /**
     * @notice Deposit USDT into the agent's budget
     */
    function depositUSDT(uint256 amount) external {
        IERC20(USDT_TOKEN).safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityInjected(msg.sender, amount);
    }

    function withdrawUSDT(address to, uint256 amount) external onlyOwner {
        IERC20(USDT_TOKEN).safeTransfer(to, amount);
    }

    function withdrawAVAX(address payable to, uint256 amount) external onlyOwner {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "AVAX transfer failed");
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function getUSDTBalance() external view returns (uint256) {
        return IERC20(USDT_TOKEN).balanceOf(address(this));
    }

    function getPaymentCount() external view returns (uint256) {
        return paymentHistory.length;
    }

    function getPaymentHistory(
        uint256 offset,
        uint256 limit
    ) external view returns (PaymentRecord[] memory) {
        uint256 total = paymentHistory.length;
        if (offset >= total) return new PaymentRecord[](0);
        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        PaymentRecord[] memory result = new PaymentRecord[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = paymentHistory[offset + i];
        }
        return result;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ERC8004_INTERFACE_ID;
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _checkAndResetBudget() internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay) {
            spentToday = 0;
            lastResetDay = currentDay;
            emit BudgetUpdated(dailyBudget, 0);
        }
    }

    receive() external payable {}
}
