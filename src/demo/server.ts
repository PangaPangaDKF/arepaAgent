/**
 * Demo x402 Server — simulates two gated resources:
 *
 *   GET /api/bcv-rate         → BCV exchange rate (0.10 USDT)
 *   GET /api/internet/open    → WiFi hotspot activation (1.00 USDT)
 *
 * Run: npm run demo
 * Then: the agent will auto-pay to access these endpoints.
 */

import "dotenv/config";
import express from "express";
import { requirePayment } from "../x402/server.js";
import { MERCHANTS } from "../blockchain/config.js";

const app = express();
app.use(express.json());

const PORT = Number(process.env.PORT ?? 3000);

// The "hotspot operator" receives payments to the panaderia wallet (for demo purposes)
// In production, this would be the ISP/router owner's wallet
const HOTSPOT_WALLET = MERCHANTS[0].address; // Panaderia El Arepazo for demo

// ─── Protected: BCV Exchange Rate ────────────────────────────────────────────
app.get(
  "/api/bcv-rate",
  requirePayment({
    priceUSDT: "0.10",
    description: "BCV official USD/VES exchange rate (real-time)",
    mimeType: "application/json",
    payTo: HOTSPOT_WALLET,
  }),
  (_req, res) => {
    // Simulated BCV rate — in production this would call BCV API
    res.json({
      source: "Banco Central de Venezuela (simulated)",
      usd_ves: 36.50,
      usdt_ves: 36.45,
      updated_at: new Date().toISOString(),
    });
  }
);

// ─── Protected: WiFi Hotspot Activation ──────────────────────────────────────
app.get(
  "/api/internet/open",
  requirePayment({
    priceUSDT: "1.00",
    description: "30 minutes of WiFi internet access via ArepaPay hotspot",
    mimeType: "application/json",
    payTo: HOTSPOT_WALLET,
    maxTimeoutSeconds: 120,
  }),
  (req, res) => {
    const txHash = (req as typeof req & { paymentTxHash: string }).paymentTxHash;
    res.json({
      status: "granted",
      minutes: 30,
      ssid: "ArepaPay-Libre",
      session_token: `sess_${txHash.slice(2, 18)}`,
      expires_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      message: "Conexion WiFi activa. Disfruta 30 minutos de internet libre!",
    });
  }
);

// ─── Health check ─────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok", server: "ArepaPay x402 Demo", wallet: HOTSPOT_WALLET });
});

app.listen(PORT, () => {
  console.log(`\n🌐 ArepaPay x402 Demo Server running on http://localhost:${PORT}`);
  console.log(`   GET /api/bcv-rate        → 0.10 USDT`);
  console.log(`   GET /api/internet/open   → 1.00 USDT`);
  console.log(`   Receiving payments at: ${HOTSPOT_WALLET}\n`);
});
