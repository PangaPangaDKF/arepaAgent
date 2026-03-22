// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title InternetVoucher
 * @dev Minutos de internet ganados al pagar en comercios ArepaPay.
 *
 * Flujo:
 *   1. PaymentProcessor llama mint(usuario, minutos) al procesar un pago.
 *   2. El usuario llama activate(minutos) para quemar sus minutos y activar acceso.
 *      Emite ActivationRequested — un router MikroTik autorizado puede escuchar este evento
 *      y abrir el portal cautivo en tiempo real.
 *   3. Para integracion real con routers: authorizeConsumer(router) + consume(user, minutes).
 */
contract InternetVoucher is Ownable {
    mapping(address => uint256) private _balance;   // minutos disponibles

    address public paymentProcessor;
    uint256 public minutesPerPayment = 30;          // configurable por el owner

    // Consumidores autorizados (routers MikroTik, backend del hotspot)
    mapping(address => bool) public authorizedConsumers;

    /* -----------------------------------------------------------------------
     *  EVENTS
     * ----------------------------------------------------------------------- */
    event MinutesMinted(address indexed to, uint256 amount);
    event ActivationRequested(address indexed user, uint256 amount, uint256 timestamp);
    event MinutesConsumed(address indexed user, uint256 amount, address indexed consumer);
    event PaymentProcessorSet(address indexed processor);
    event ConsumerAuthorized(address indexed consumer, bool authorized);

    /* -----------------------------------------------------------------------
     *  CONSTRUCTOR
     * ----------------------------------------------------------------------- */
    constructor() Ownable(msg.sender) {}

    /* -----------------------------------------------------------------------
     *  CONFIGURACION (owner)
     * ----------------------------------------------------------------------- */
    function setPaymentProcessor(address _processor) external onlyOwner {
        require(_processor != address(0), "IV: zero address");
        paymentProcessor = _processor;
        emit PaymentProcessorSet(_processor);
    }

    function setMinutesPerPayment(uint256 _minutes) external onlyOwner {
        require(_minutes > 0, "IV: must be > 0");
        minutesPerPayment = _minutes;
    }

    function setConsumer(address _consumer, bool _authorized) external onlyOwner {
        authorizedConsumers[_consumer] = _authorized;
        emit ConsumerAuthorized(_consumer, _authorized);
    }

    /* -----------------------------------------------------------------------
     *  MINT — solo PaymentProcessor
     * ----------------------------------------------------------------------- */
    function mint(address to, uint256 minutes_) external {
        require(msg.sender == paymentProcessor, "IV: not authorized");
        require(to != address(0), "IV: zero address");
        _balance[to] += minutes_;
        emit MinutesMinted(to, minutes_);
    }

    /* -----------------------------------------------------------------------
     *  ACTIVATE — el usuario quema sus minutos y pide activacion
     *  El evento ActivationRequested puede ser escuchado por un backend/router
     * ----------------------------------------------------------------------- */
    function activate(uint256 minutes_) external {
        require(_balance[msg.sender] >= minutes_, "IV: saldo insuficiente");
        require(minutes_ > 0, "IV: minutos must be > 0");
        _balance[msg.sender] -= minutes_;
        emit ActivationRequested(msg.sender, minutes_, block.timestamp);
    }

    /* -----------------------------------------------------------------------
     *  CONSUME — para integracion con router real (MikroTik, UniFi, etc.)
     * ----------------------------------------------------------------------- */
    function consume(address user, uint256 minutes_) external {
        require(authorizedConsumers[msg.sender], "IV: consumer not authorized");
        require(_balance[user] >= minutes_, "IV: saldo insuficiente");
        _balance[user] -= minutes_;
        emit MinutesConsumed(user, minutes_, msg.sender);
    }

    /* -----------------------------------------------------------------------
     *  VIEW
     * ----------------------------------------------------------------------- */
    function balanceOf(address user) external view returns (uint256) {
        return _balance[user];
    }
}
