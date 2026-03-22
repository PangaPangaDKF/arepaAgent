/**
 * Arbitrage tools for ArepaAgent.
 *
 * Strategy (from HACKATHON_MASTER.md):
 *   1. Check ArepaHub internal USDT rate vs external market (Binance/BCV)
 *   2. If spread > threshold (default 3%), execute arbitrage
 *   3. Buy USDT from OTCMarket at lower price, sell externally at higher price
 *   4. Inject 100% of profits back into ArepaHub liquidity
 *
 * This keeps ArepaHub solvent and earns yield that flows to SavingsVault (sUSDT holders).
 */

import { ethers } from "ethers";
import { getWallet } from "../blockchain/wallet.js";
import { CONTRACTS, USDT_DECIMALS } from "../blockchain/config.js";
import { AREPA_HUB_ABI, OTC_MARKET_ABI, ERC20_ABI } from "../blockchain/abis.js";

export interface MarketPrices {
  arepaHubRate: number;      // USDT/VES rate offered by ArepaHub (BCV + margin)
  externalRate: number;      // Simulated external market rate (Binance P2P / BCV)
  spread: number;            // Percentage difference
  spreadAboveThreshold: boolean;
}

export interface ArbitrageResult {
  executed: boolean;
  reason?: string;
  boughtUSDT?: string;
  profitUSDT?: string;
  injectTxHash?: string;
  error?: string;
}

/**
 * Fetch current USDT/VES rate from Binance P2P public API.
 * No API key required — uses the public c2c search endpoint.
 * Falls back to BCV reference rate if the request fails.
 */
async function getBinanceP2PRate(): Promise<number> {
  try {
    const { default: axios } = await import("axios");
    const response = await axios.post(
      "https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search",
      {
        asset: "USDT",
        fiat: "VES",
        merchantCheck: false,
        page: 1,
        payTypes: [],
        publisherType: null,
        rows: 5,
        tradeType: "BUY",
      },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 5000,
      }
    );
    const ads = response.data?.data as Array<{ adv: { price: string } }> | undefined;
    if (ads && ads.length > 0) {
      const prices = ads.map((ad) => parseFloat(ad.adv.price));
      // Median of top 5 BUY offers
      prices.sort((a, b) => a - b);
      return prices[Math.floor(prices.length / 2)];
    }
  } catch {
    // Silently fall through to fallback
  }
  return 36.50; // BCV reference fallback
}

/**
 * Fetch current rates — ArepaHub internal vs Binance P2P market.
 * External rate pulled live from Binance P2P USDT/VES public endpoint.
 */
export async function getMarketPrices(spreadThresholdPct = 3): Promise<MarketPrices> {
  const wallet = getWallet();
  const hub = new ethers.Contract(CONTRACTS.arepaHub, AREPA_HUB_ABI, wallet);

  let arepaHubRate: number;
  try {
    const priceCents = await hub.sellPriceCents();
    // sellPriceCents() returns centavos de Bs por USDT — divide by 100 to get Bs/USDT
    arepaHubRate = Number(priceCents) / 100;
  } catch {
    // ArepaHub not deployed or L1 not running — use reference rate
    arepaHubRate = 37.5; // 1 USDT = 37.5 VES (BCV rate + 2% margin)
  }

  const externalRate = await getBinanceP2PRate();
  const spread = ((arepaHubRate - externalRate) / externalRate) * 100;

  return {
    arepaHubRate,
    externalRate,
    spread: Math.abs(spread),
    spreadAboveThreshold: Math.abs(spread) >= spreadThresholdPct,
  };
}

/**
 * Check ArepaHub total liquidity available.
 */
export async function getHubLiquidity(): Promise<{ totalUSDT: string; canOperate: boolean }> {
  const wallet = getWallet();
  const hub = new ethers.Contract(CONTRACTS.arepaHub, AREPA_HUB_ABI, wallet);

  try {
    const total = await hub.treasuryBalance();
    const totalUSDT = ethers.formatUnits(total, USDT_DECIMALS);
    return { totalUSDT, canOperate: Number(totalUSDT) > 10 };
  } catch {
    return { totalUSDT: "0", canOperate: false };
  }
}

/**
 * Inject USDT profits back into ArepaHub to maintain liquidity.
 * Called after a successful arbitrage cycle.
 */
export async function injectLiquidity(amountUSDT: string): Promise<{ txHash: string } | { error: string }> {
  const wallet = getWallet();
  const usdt = new ethers.Contract(CONTRACTS.mockUSDT, ERC20_ABI, wallet);
  const hub = new ethers.Contract(CONTRACTS.arepaHub, AREPA_HUB_ABI, wallet);

  const amount = ethers.parseUnits(amountUSDT, USDT_DECIMALS);

  try {
    const approveTx = await usdt.approve(CONTRACTS.arepaHub, amount);
    await approveTx.wait();

    const injectTx = await hub.inject(amount);
    const receipt = await injectTx.wait();

    return { txHash: receipt.hash };
  } catch (err) {
    return { error: (err as Error).message };
  }
}

/**
 * Execute full arbitrage cycle:
 *   1. Check market spread
 *   2. If profitable: simulate buying cheap + injecting back into hub
 *   3. Return result with profit estimation
 *
 * Note: For the hackathon demo, step 2 is simulated (real Binance API not integrated).
 * The on-chain injection IS real.
 */
export async function executeArbitrage(
  maxCapitalUSDT = "50",
  spreadThresholdPct = 3
): Promise<ArbitrageResult> {
  const prices = await getMarketPrices(spreadThresholdPct);

  if (!prices.spreadAboveThreshold) {
    return {
      executed: false,
      reason: `Spread ${prices.spread.toFixed(2)}% below threshold ${spreadThresholdPct}%. No arbitrage opportunity.`,
    };
  }

  const hubLiquidity = await getHubLiquidity();
  if (!hubLiquidity.canOperate) {
    return {
      executed: false,
      reason: `ArepaHub liquidity too low (${hubLiquidity.totalUSDT} USDT). Cannot operate.`,
    };
  }

  // Calculate profit: spread × capital
  const capital = Math.min(Number(maxCapitalUSDT), Number(hubLiquidity.totalUSDT));
  const profitUSDT = (capital * (prices.spread / 100)).toFixed(2);

  console.log(`[arbitrage] 📊 Spread: ${prices.spread.toFixed(2)}% | Capital: ${capital} USDT | Est. profit: ${profitUSDT} USDT`);
  console.log(`[arbitrage] 💹 Hub rate: ${prices.arepaHubRate} VES/USDT | External: ${prices.externalRate} VES/USDT`);

  // Inject simulated profit back into ArepaHub
  // (In production: real arbitrage trade occurs here)
  const injectResult = await injectLiquidity(profitUSDT);

  if ("error" in injectResult) {
    return { executed: false, error: `Failed to inject profits: ${injectResult.error}` };
  }

  return {
    executed: true,
    boughtUSDT: capital.toFixed(2),
    profitUSDT,
    injectTxHash: injectResult.txHash,
  };
}
