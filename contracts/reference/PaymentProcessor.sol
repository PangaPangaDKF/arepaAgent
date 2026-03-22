// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 }   from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable }  from "@openzeppelin/contracts/access/Ownable.sol";
import { MerchantRegistry } from "./MerchantRegistry.sol";

interface IRewardTicket {
    function mint(address to) external;
}

interface IRaffle {
    function recordTransaction() external;
}

interface IInternetVoucher {
    function mint(address to, uint256 minutes_) external;
    function minutesPerPayment() external view returns (uint256);
}

contract PaymentProcessor is Ownable {
    MerchantRegistry  public registry;
    IERC20            public usdt;
    IRewardTicket     public rewardTicket;
    IRaffle           public raffle;
    IInternetVoucher  public internetVoucher;

    event PaymentSent(address indexed from, address indexed to, uint256 amount);

    constructor(
        address _registry,
        address _usdt,
        address _rewardTicket,
        address _raffle,
        address _internetVoucher
    ) Ownable(msg.sender) {
        registry        = MerchantRegistry(_registry);
        usdt            = IERC20(_usdt);
        rewardTicket    = IRewardTicket(_rewardTicket);
        raffle          = IRaffle(_raffle);
        internetVoucher = IInternetVoucher(_internetVoucher);
    }

    function payMerchant(address _merchant, uint256 _amount) external {
        require(registry.isMerchant(_merchant), "Comercio no verificado en ArepaPay");
        require(msg.sender != _merchant, "No puedes pagarte a ti mismo");
        require(usdt.transferFrom(msg.sender, _merchant, _amount), "Fallo en la transferencia");

        // Solo el pagador recibe el ticket — el comercio no participa en rifas
        rewardTicket.mint(msg.sender);

        // Minutos de internet solo al pagador
        try internetVoucher.mint(msg.sender, internetVoucher.minutesPerPayment()) {} catch {}

        // Registrar en sistema de rifas
        try raffle.recordTransaction() {} catch {}

        emit PaymentSent(msg.sender, _merchant, _amount);
    }

    /* -----------------------------------------------------------------------
     *  ADMIN
     * ----------------------------------------------------------------------- */
    function updateRegistry(address _new) external onlyOwner {
        registry = MerchantRegistry(_new);
    }

    function updateRewardTicket(address _new) external onlyOwner {
        rewardTicket = IRewardTicket(_new);
    }

    function updateRaffle(address _new) external onlyOwner {
        raffle = IRaffle(_new);
    }

    function updateInternetVoucher(address _new) external onlyOwner {
        internetVoucher = IInternetVoucher(_new);
    }
}
