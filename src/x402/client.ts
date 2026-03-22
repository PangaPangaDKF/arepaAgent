/**
 * x402 Client — autonomous HTTP client that handles 402 Payment Required
 *
 * Flow:
 *   1. Make HTTP request to resource
 *   2. If 402 → parse X402PaymentRequired from response body
 *   3. Pay on-chain via direct ERC20.transfer() (no merchant registry required)
 *   4. Retry request with X-Payment header (tx hash as proof)
 *   5. Return data if 200
 */

import axios, { AxiosRequestConfig, AxiosResponse } from "axios";
import { ethers } from "ethers";
import type { X402PaymentRequired, X402PaymentHeader, X402Response } from "./types.js";
import { getWallet } from "../blockchain/wallet.js";
import { CONTRACTS, USDT_DECIMALS } from "../blockchain/config.js";
import { ERC20_ABI } from "../blockchain/abis.js";

export interface FetchWithPaymentOptions extends AxiosRequestConfig {
  maxAutoPayUSDT?: number; // Refuse to auto-pay above this amount (default: 5 USDT)
}

export async function fetchWithPayment<T = unknown>(
  url: string,
  options: FetchWithPaymentOptions = {}
): Promise<X402Response<T>> {
  const { maxAutoPayUSDT = 5, ...axiosOptions } = options;
  const wallet = getWallet();

  // --- First attempt ---
  let response: AxiosResponse;
  try {
    response = await axios({ url, ...axiosOptions, validateStatus: () => true });
  } catch (err) {
    return { paid: false, error: `Network error: ${(err as Error).message}` };
  }

  if (response.status !== 402) {
    return { paid: true, data: response.data as T };
  }

  // --- Parse 402 payment requirements ---
  const paymentReq = response.data as X402PaymentRequired;

  if (!paymentReq.payTo || !paymentReq.maxAmountRequired) {
    return { paid: false, error: "Invalid 402 response: missing payTo or maxAmountRequired", paymentRequired: paymentReq };
  }

  const amountUSDT = ethers.formatUnits(paymentReq.maxAmountRequired, USDT_DECIMALS);
  const amountNum = parseFloat(amountUSDT);

  if (amountNum > maxAutoPayUSDT) {
    return {
      paid: false,
      error: `Auto-pay refused: ${amountUSDT} USDT exceeds limit of ${maxAutoPayUSDT} USDT`,
      paymentRequired: paymentReq,
    };
  }

  // Verify the resource is asking for our supported asset (MockUSDT on Fuji)
  if (paymentReq.asset.toLowerCase() !== CONTRACTS.mockUSDT.toLowerCase()) {
    return {
      paid: false,
      error: `Unsupported payment asset: ${paymentReq.asset}. Expected MockUSDT: ${CONTRACTS.mockUSDT}`,
      paymentRequired: paymentReq,
    };
  }

  console.log(`[x402] 💳 Auto-paying ${amountUSDT} USDT to ${paymentReq.payTo} for: ${paymentReq.description}`);

  // --- Execute payment on-chain (direct USDT transfer — no merchant registry required) ---
  // x402 payments go to any service/API, not only registered merchants.
  let txHash: string;
  try {
    const usdt = new ethers.Contract(CONTRACTS.mockUSDT, ERC20_ABI, wallet);
    const amount = ethers.parseUnits(amountUSDT, USDT_DECIMALS);
    const tx = await usdt.transfer(paymentReq.payTo, amount);
    const receipt = await tx.wait();
    txHash = receipt.hash;
  } catch (err) {
    return { paid: false, error: `Payment failed: ${(err as Error).message}`, paymentRequired: paymentReq };
  }

  console.log(`[x402] ✅ Payment confirmed: ${txHash}`);

  // --- Build payment proof header ---
  const now = Math.floor(Date.now() / 1000);
  const paymentHeader: X402PaymentHeader = {
    scheme: "exact",
    network: "evm",
    payload: {
      signature: txHash,
      authorization: {
        from: wallet.address,
        to: paymentReq.payTo,
        value: paymentReq.maxAmountRequired,
        validAfter: now - 60,
        validBefore: now + 300,
        nonce: `${Date.now()}`,
      },
    },
  };

  // --- Retry request with payment proof ---
  const retryResponse = await axios({
    url,
    ...axiosOptions,
    headers: {
      ...(axiosOptions.headers ?? {}),
      "X-Payment": Buffer.from(JSON.stringify(paymentHeader)).toString("base64"),
      "X-Payment-TxHash": txHash,
    },
    validateStatus: () => true,
  });

  if (retryResponse.status === 200) {
    return { paid: true, data: retryResponse.data as T };
  }

  return {
    paid: false,
    error: `Server rejected payment proof. Status: ${retryResponse.status}`,
    paymentRequired: paymentReq,
  };
}
