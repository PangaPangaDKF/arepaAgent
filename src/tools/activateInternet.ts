import { ethers } from "ethers";
import { getWallet } from "../blockchain/wallet.js";
import { CONTRACTS } from "../blockchain/config.js";
import { INTERNET_VOUCHER_ABI } from "../blockchain/abis.js";

export interface ActivationResult {
  success: boolean;
  txHash?: string;
  minutesActivated?: number;
  remainingMinutes?: number;
  error?: string;
}

export async function activateInternet(minutes: number): Promise<ActivationResult> {
  const wallet = getWallet();
  const voucher = new ethers.Contract(CONTRACTS.internetVoucher, INTERNET_VOUCHER_ABI, wallet);

  const balance: bigint = await voucher.balanceOf(wallet.address);
  const balanceNum = Number(balance);

  if (balanceNum < minutes) {
    return {
      success: false,
      error: `Insufficient internet minutes. Have ${balanceNum}, requested ${minutes}.`,
    };
  }

  // Emits ActivationRequested(user, amount, timestamp) — off-chain router listens to this
  const tx = await voucher.activate(minutes);
  const receipt = await tx.wait();

  const remaining = balanceNum - minutes;

  return {
    success: true,
    txHash: receipt.hash,
    minutesActivated: minutes,
    remainingMinutes: remaining,
  };
}
