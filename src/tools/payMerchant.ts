import { ethers } from "ethers";
import { getWallet } from "../blockchain/wallet.js";
import { CONTRACTS, MERCHANTS, USDT_DECIMALS } from "../blockchain/config.js";
import { ERC20_ABI, PAYMENT_PROCESSOR_ABI, MERCHANT_REGISTRY_ABI } from "../blockchain/abis.js";

export interface PaymentResult {
  success: boolean;
  txHash?: string;
  merchantName?: string;
  amount: string;
  error?: string;
}

export async function payMerchant(
  merchantAddress: string,
  amountUSDT: string
): Promise<PaymentResult> {
  const wallet = getWallet();
  const amount = ethers.parseUnits(amountUSDT, USDT_DECIMALS);

  // Verify merchant is registered before attempting payment
  const registry = new ethers.Contract(CONTRACTS.merchantRegistry, MERCHANT_REGISTRY_ABI, wallet);
  const isVerified: boolean = await registry.isMerchant(merchantAddress);
  if (!isVerified) {
    return { success: false, amount: amountUSDT, error: `Address ${merchantAddress} is not a verified ArepaPay merchant` };
  }

  const merchantInfo = await registry.merchants(merchantAddress);
  const merchantName = merchantInfo.name as string;

  const usdt = new ethers.Contract(CONTRACTS.mockUSDT, ERC20_ABI, wallet);
  const processor = new ethers.Contract(CONTRACTS.paymentProcessor, PAYMENT_PROCESSOR_ABI, wallet);

  // Step 1: approve PaymentProcessor to spend USDT
  const approveTx = await usdt.approve(CONTRACTS.paymentProcessor, amount);
  await approveTx.wait();

  // Step 2: execute payment — triggers ticket + internet voucher minting
  const payTx = await processor.payMerchant(merchantAddress, amount);
  const receipt = await payTx.wait();

  return {
    success: true,
    txHash: receipt.hash,
    merchantName,
    amount: amountUSDT,
  };
}

/** Convenience: pay by merchant ID (panaderia, botellones, perros, bodega) */
export async function payMerchantById(
  merchantId: string,
  amountUSDT: string
): Promise<PaymentResult> {
  const merchant = MERCHANTS.find((m) => m.id === merchantId);
  if (!merchant) {
    return {
      success: false,
      amount: amountUSDT,
      error: `Unknown merchant id "${merchantId}". Available: ${MERCHANTS.map((m) => m.id).join(", ")}`,
    };
  }
  return payMerchant(merchant.address, amountUSDT);
}
