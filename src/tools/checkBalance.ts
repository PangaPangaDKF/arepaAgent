import { ethers } from "ethers";
import { getProvider, getWallet } from "../blockchain/wallet.js";
import { CONTRACTS, USDT_DECIMALS } from "../blockchain/config.js";
import {
  ERC20_ABI,
  REWARD_TICKET_ABI,
  INTERNET_VOUCHER_ABI,
} from "../blockchain/abis.js";

export interface Balances {
  address: string;
  usdt: string;       // formatted (e.g. "15.50")
  avax: string;       // native gas token
  tickets: string;    // raffle tickets (integer)
  internetMinutes: string; // WiFi minutes available
}

export async function checkBalance(address?: string): Promise<Balances> {
  const provider = getProvider();
  const wallet = getWallet();
  const target = address ?? wallet.address;

  const usdt = new ethers.Contract(CONTRACTS.mockUSDT, ERC20_ABI, provider);
  const ticket = new ethers.Contract(CONTRACTS.rewardTicket, REWARD_TICKET_ABI, provider);
  const voucher = new ethers.Contract(CONTRACTS.internetVoucher, INTERNET_VOUCHER_ABI, provider);

  const [rawUsdt, rawAvax, rawTickets, rawMinutes] = await Promise.all([
    usdt.balanceOf(target),
    provider.getBalance(target),
    ticket.balanceOf(target),
    voucher.balanceOf(target),
  ]);

  return {
    address: target,
    usdt: ethers.formatUnits(rawUsdt, USDT_DECIMALS),
    avax: ethers.formatEther(rawAvax),
    tickets: rawTickets.toString(),
    internetMinutes: rawMinutes.toString(),
  };
}
