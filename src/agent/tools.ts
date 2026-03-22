/**
 * Claude tool definitions for the arepaAgent.
 * These are the tools Claude can call to interact with ArepaPay contracts
 * and make x402 HTTP requests.
 */

import Anthropic from "@anthropic-ai/sdk";

export const AGENT_TOOLS: Anthropic.Tool[] = [
  {
    name: "check_balance",
    description:
      "Check USDT balance, AVAX balance, raffle tickets, and internet minutes for a wallet address. If no address is provided, checks the agent's own wallet.",
    input_schema: {
      type: "object" as const,
      properties: {
        address: {
          type: "string",
          description: "Wallet address to check. Optional — defaults to agent wallet.",
        },
      },
    },
  },
  {
    name: "pay_merchant",
    description:
      "Pay a verified ArepaPay merchant using USDT via PaymentProcessor. This triggers automatic minting of 1 raffle ticket and 30 internet minutes for the payer. Use merchant_id for known merchants or merchant_address for direct payment.",
    input_schema: {
      type: "object" as const,
      properties: {
        merchant_id: {
          type: "string",
          description:
            "Known merchant ID: 'panaderia', 'botellones', 'perros', or 'bodega'",
        },
        merchant_address: {
          type: "string",
          description: "Direct wallet address of a verified merchant (alternative to merchant_id)",
        },
        amount_usdt: {
          type: "string",
          description: "Amount in USDT to pay (e.g. '5.00', '10.50')",
        },
      },
      required: ["amount_usdt"],
    },
  },
  {
    name: "activate_internet",
    description:
      "Activate WiFi internet minutes from the agent's InternetVoucher balance. Emits an on-chain event that the router (MikroTik/UniFi) listens to in order to open the captive portal.",
    input_schema: {
      type: "object" as const,
      properties: {
        minutes: {
          type: "number",
          description: "Number of minutes to activate (must not exceed available balance)",
        },
      },
      required: ["minutes"],
    },
  },
  {
    name: "get_market_prices",
    description:
      "Compare USDT rates: ArepaHub internal rate vs external market (Binance P2P / BCV official). Returns spread percentage and whether arbitrage is profitable.",
    input_schema: {
      type: "object" as const,
      properties: {
        spread_threshold_pct: {
          type: "number",
          description: "Minimum spread % to consider profitable. Default: 3",
        },
      },
    },
  },
  {
    name: "get_hub_liquidity",
    description:
      "Check total USDT liquidity available in ArepaHub (the merchant liquidity bridge).",
    input_schema: {
      type: "object" as const,
      properties: {},
    },
  },
  {
    name: "execute_arbitrage",
    description:
      "Execute an arbitrage cycle: detect spread between ArepaHub internal rate and external market, simulate the trade, and inject profits back into ArepaHub to maintain ecosystem liquidity.",
    input_schema: {
      type: "object" as const,
      properties: {
        max_capital_usdt: {
          type: "string",
          description: "Maximum USDT to deploy in the arbitrage. Default: 50",
        },
        spread_threshold_pct: {
          type: "number",
          description: "Minimum spread % before executing. Default: 3",
        },
      },
    },
  },
  {
    name: "inject_liquidity",
    description:
      "Inject USDT directly into ArepaHub to increase available merchant liquidity. Used after profitable arbitrage.",
    input_schema: {
      type: "object" as const,
      properties: {
        amount_usdt: {
          type: "string",
          description: "Amount of USDT to inject into ArepaHub",
        },
      },
      required: ["amount_usdt"],
    },
  },
  {
    name: "fetch_with_payment",
    description:
      "Make an HTTP request to a URL. If the server responds with HTTP 402 (x402 protocol), automatically pays the required USDT amount using ArepaPay and retries the request. Returns the response data.",
    input_schema: {
      type: "object" as const,
      properties: {
        url: {
          type: "string",
          description: "URL to fetch (may return 402 requiring payment)",
        },
        max_auto_pay_usdt: {
          type: "number",
          description: "Maximum USDT to auto-pay without asking. Default: 5",
        },
      },
      required: ["url"],
    },
  },
];
