/**
 * ArepaAgent — Groq Edition (completamente gratis)
 *
 * Usa llama-3.3-70b-versatile via Groq API (OpenAI-compatible format).
 * Registro gratis en console.groq.com — sin tarjeta de crédito.
 *
 * Requiere en .env:
 *   GROQ_API_KEY=gsk_...
 *   WDK_SEED=word1 word2 ... word12
 *
 * Usage:
 *   npm run dev:groq
 */

import "dotenv/config";
import OpenAI from "openai";
import * as readline from "readline";
import type { ChatCompletionMessageParam, ChatCompletionTool } from "openai/resources/chat/completions";
import { AGENT_TOOLS } from "./tools.js";
import { processToolCall } from "../tools/dispatch.js";

const client = new OpenAI({
  baseURL: "https://api.groq.com/openai/v1",
  apiKey: process.env.GROQ_API_KEY,
});

const MODEL = "llama-3.3-70b-versatile";

const SYSTEM_PROMPT = `You are ArepaAgent, an autonomous Web3 payment and arbitrage agent for the ArepaPay ecosystem on a custom Avalanche L1 (Chain ID 13370).

You can autonomously:
- Check USDT, raffle ticket, and internet minute balances
- Pay verified Venezuelan merchants via PaymentProcessor (earns +1 ticket + 30 WiFi min per payment)
- Activate WiFi internet vouchers on-chain (captive portal event listener)
- Fetch x402-gated HTTP resources and auto-pay when HTTP 402 is returned
- Monitor ArepaHub internal USDT rates vs external market (BCV/Binance)
- Execute arbitrage cycles when spread > 3% and inject profits back into ArepaHub
- Check and report ArepaHub liquidity health

Key context:
- Network: ArepaPay L1 (Chain ID 13370), AREPA as native gas token
- USDT uses 6 decimals (real USDT standard, not 18)
- ArepaHub is the merchant liquidity bridge (internal USDT ↔ Bolivares)
- OTCMarket enables P2P Bs↔USDT trades
- RevenueDistributor: 40% to prizes, 30% to merchants, 25% to devs, 5% reserve
- x402 protocol: HTTP 402 → auto-pay on-chain → retry with payment proof header
- All payments flow through PaymentProcessor, no escrow, direct wallet-to-wallet

Be concise and action-oriented. Use tools to complete tasks. Always confirm tx hashes.`;

/** Convert Anthropic tool format → OpenAI/Groq tool format */
const GROQ_TOOLS: ChatCompletionTool[] = AGENT_TOOLS.map((t) => ({
  type: "function",
  function: {
    name: t.name,
    description: t.description ?? "",
    parameters: t.input_schema as Record<string, unknown>,
  },
}));

async function runAgent(
  userMessage: string,
  history: ChatCompletionMessageParam[]
): Promise<ChatCompletionMessageParam[]> {
  const messages: ChatCompletionMessageParam[] = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history,
    { role: "user", content: userMessage },
  ];

  console.log("\n🤖 ArepaAgent (Groq) thinking...\n");

  // Agentic loop
  while (true) {
    const response = await client.chat.completions.create({
      model: MODEL,
      messages,
      tools: GROQ_TOOLS,
      tool_choice: "auto",
    });

    const choice = response.choices[0];
    messages.push(choice.message);

    if (choice.finish_reason === "stop" || !choice.message.tool_calls?.length) {
      if (choice.message.content) {
        console.log(`\n💬 ${choice.message.content}\n`);
      }
      break;
    }

    if (choice.finish_reason === "tool_calls") {
      for (const tc of choice.message.tool_calls) {
        let input: Record<string, unknown>;
        try {
          input = JSON.parse(tc.function.arguments) as Record<string, unknown>;
        } catch {
          input = {};
        }

        console.log(`\n🔧 Tool: ${tc.function.name}`);
        console.log(`   Input: ${tc.function.arguments}`);

        const result = await processToolCall(tc.function.name, input);

        console.log(`   Result: ${result.slice(0, 200)}${result.length > 200 ? "..." : ""}`);

        messages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: result,
        });
      }
    }
  }

  // Return history without the system prompt (added fresh each call)
  return messages.slice(1);
}

// ─── Interactive REPL ─────────────────────────────────────────────────────────
async function main() {
  if (!process.env.GROQ_API_KEY) {
    console.error("❌ GROQ_API_KEY not set. Register free at https://console.groq.com → API Keys");
    process.exit(1);
  }

  console.log("┌──────────────────────────────────────────────┐");
  console.log("│  🫓  ArepaAgent — Groq Edition (gratis)       │");
  console.log("│     llama-3.3-70b-versatile | ArepaPay L1    │");
  console.log("└──────────────────────────────────────────────┘");
  console.log('\nType your request (e.g. "check my balance") or "exit" to quit.\n');

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let history: ChatCompletionMessageParam[] = [];
  let closed = false;

  rl.on("close", () => { closed = true; });

  const ask = () => {
    if (closed) return;
    rl.question("You: ", async (input) => {
      const trimmed = input.trim();
      if (!trimmed || trimmed.toLowerCase() === "exit") {
        console.log("Hasta luego! 🫓");
        rl.close();
        return;
      }
      try {
        history = await runAgent(trimmed, history);
      } catch (err) {
        console.error(`\n❌ Error: ${(err as Error).message}\n`);
      }
      ask();
    });
  };

  ask();
}

main().catch(console.error);
