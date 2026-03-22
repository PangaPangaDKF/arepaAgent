// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FeeDistributor
 * @notice Recibe fees de PaymentProcessor y los redistribuye al ecosistema ArepaPay.
 *
 * Distribución por defecto:
 *   30% → validadores (o multisig de validadores)
 *   30% → merchant stakers / LPs
 *   40% → prize pool (rifas, vouchers, incentivos)
 *
 * FASE 1 (MVP L1): el owner hace distribute() manualmente.
 * FASE 5 (Governance): AREPA holders votan los porcentajes.
 */
contract FeeDistributor is Ownable {
    IERC20 public usdt;

    address public validatorsPool;
    address public merchantPool;
    address public prizePool;

    uint256 public validatorsBps = 3000; // 30%
    uint256 public merchantBps   = 3000; // 30%
    uint256 public prizeBps      = 4000; // 40%

    uint256 public totalCollected;

    event FeesReceived(address indexed from, uint256 amount);
    event FeesDistributed(uint256 toValidators, uint256 toMerchants, uint256 toPrize);
    event PoolsUpdated(address validators, address merchants, address prize);

    constructor(
        address _usdt,
        address _validatorsPool,
        address _merchantPool,
        address _prizePool
    ) Ownable(msg.sender) {
        usdt = IERC20(_usdt);
        validatorsPool = _validatorsPool;
        merchantPool   = _merchantPool;
        prizePool      = _prizePool;
    }

    /**
     * @notice Llamado por PaymentProcessor al cobrar cada fee.
     *         Requiere que PaymentProcessor haya aprobado esta dirección.
     */
    function receiveFee(uint256 amount) external {
        require(usdt.transferFrom(msg.sender, address(this), amount), "FeeDistributor: transfer failed");
        totalCollected += amount;
        emit FeesReceived(msg.sender, amount);
    }

    /**
     * @notice Distribuye el balance acumulado según los porcentajes configurados.
     *         En MVP: el owner lo llama periódicamente (diario / semanal).
     */
    function distribute() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        require(balance > 0, "FeeDistributor: nothing to distribute");

        uint256 toValidators = (balance * validatorsBps) / 10000;
        uint256 toMerchants  = (balance * merchantBps)   / 10000;
        uint256 toPrize      = balance - toValidators - toMerchants; // remanente al prize pool

        if (toValidators > 0) usdt.transfer(validatorsPool, toValidators);
        if (toMerchants  > 0) usdt.transfer(merchantPool,   toMerchants);
        if (toPrize      > 0) usdt.transfer(prizePool,      toPrize);

        emit FeesDistributed(toValidators, toMerchants, toPrize);
    }

    /**
     * @notice Actualizar las direcciones de los pools de destino.
     */
    function setPools(
        address _validators,
        address _merchants,
        address _prize
    ) external onlyOwner {
        validatorsPool = _validators;
        merchantPool   = _merchants;
        prizePool      = _prize;
        emit PoolsUpdated(_validators, _merchants, _prize);
    }

    /**
     * @notice Actualizar porcentajes (suma debe ser 10000 = 100%).
     */
    function setBps(
        uint256 _validatorsBps,
        uint256 _merchantBps,
        uint256 _prizeBps
    ) external onlyOwner {
        require(_validatorsBps + _merchantBps + _prizeBps == 10000, "FeeDistributor: must sum to 10000");
        validatorsBps = _validatorsBps;
        merchantBps   = _merchantBps;
        prizeBps      = _prizeBps;
    }
}
