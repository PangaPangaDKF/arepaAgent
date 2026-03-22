/**
 * x402 Express Middleware
 *
 * Wraps any Express route to require ArepaPay payment before serving.
 * The middleware:
 *   1. Checks for X-Payment header
 *   2. If absent → responds 402 with payment requirements
 *   3. If present → validates tx hash on-chain
 *   4. If valid → calls next() (serves the resource)
 */

import { Request, Response, NextFunction } from "express";
import { ethers } from "ethers";
import { getProvider } from "../blockchain/wallet.js";
import { CONTRACTS, USDT_DECIMALS } from "../blockchain/config.js";
import { PAYMENT_PROCESSOR_ABI } from "../blockchain/abis.js";
import type { X402PaymentRequired, X402PaymentHeader } from "./types.js";

export interface X402MiddlewareOptions {
  /** Amount in USDT (will be converted to wei) */
  priceUSDT: string;
  /** Human-readable description of what this resource provides */
  description: string;
  /** MIME type of the protected resource */
  mimeType?: string;
  /** Wallet address to receive the payment */
  payTo: string;
  /** Seconds before payment proof expires */
  maxTimeoutSeconds?: number;
}

/** Set of already-processed tx hashes to prevent double-spend */
const usedPayments = new Set<string>();

export function requirePayment(opts: X402MiddlewareOptions) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const paymentHeader = req.headers["x-payment"] as string | undefined;
    const txHashHeader = req.headers["x-payment-txhash"] as string | undefined;

    // No payment attached → return 402
    if (!paymentHeader && !txHashHeader) {
      const paymentRequired: X402PaymentRequired = {
        scheme: "exact",
        network: "evm",
        maxAmountRequired: ethers.parseUnits(opts.priceUSDT, USDT_DECIMALS).toString(),
        resource: `${req.protocol}://${req.get("host")}${req.originalUrl}`,
        description: opts.description,
        mimeType: opts.mimeType ?? "application/json",
        payTo: opts.payTo,
        maxTimeoutSeconds: opts.maxTimeoutSeconds ?? 300,
        asset: CONTRACTS.mockUSDT,
        extra: { name: "MockUSDT", version: "1" },
      };

      res.status(402).json(paymentRequired);
      return;
    }

    // Validate payment proof
    try {
      let txHash: string | undefined = txHashHeader;

      if (paymentHeader && !txHash) {
        const decoded = Buffer.from(paymentHeader, "base64").toString("utf-8");
        const proof = JSON.parse(decoded) as X402PaymentHeader;
        txHash = proof.payload.signature;
      }

      if (!txHash) {
        res.status(402).json({ error: "Missing transaction hash in payment proof" });
        return;
      }

      // Prevent replays
      if (usedPayments.has(txHash)) {
        res.status(402).json({ error: "Payment already used (replay detected)" });
        return;
      }

      // Verify tx on-chain: must be a PaymentSent event to our address
      const provider = getProvider();
      const receipt = await provider.getTransactionReceipt(txHash);

      if (!receipt) {
        res.status(402).json({ error: "Transaction not found on-chain yet" });
        return;
      }

      // Parse PaymentSent event from PaymentProcessor
      const processor = new ethers.Contract(
        CONTRACTS.paymentProcessor,
        PAYMENT_PROCESSOR_ABI,
        provider
      );

      let paymentValid = false;
      for (const log of receipt.logs) {
        try {
          const parsed = processor.interface.parseLog({ topics: log.topics as string[], data: log.data });
          if (
            parsed?.name === "PaymentSent" &&
            (parsed.args.to as string).toLowerCase() === opts.payTo.toLowerCase()
          ) {
            const paidAmount = parsed.args.amount as bigint;
            const required = ethers.parseUnits(opts.priceUSDT, USDT_DECIMALS);
            if (paidAmount >= required) {
              paymentValid = true;
              break;
            }
          }
        } catch {
          // Not a PaymentSent log, skip
        }
      }

      if (!paymentValid) {
        res.status(402).json({
          error: `No valid PaymentSent event found to ${opts.payTo} for at least ${opts.priceUSDT} USDT`,
        });
        return;
      }

      usedPayments.add(txHash);
      (req as Request & { paymentTxHash: string }).paymentTxHash = txHash;
      next();
    } catch (err) {
      res.status(402).json({ error: `Payment validation failed: ${(err as Error).message}` });
    }
  };
}
