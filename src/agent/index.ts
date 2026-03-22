/**
 * ArepaAgent — Autonomous x402 Payment Agent
 *
 * An AI agent (Claude) that can:
 *   • Check ArepaPay balances (USDT, tickets, internet minutes)
 *   • Pay verified ArepaPay merchants autonomously
 *   • Activate WiFi internet vouchers on-chain
 *   • Fetch x402-gated resources and auto-pay when 402 is returned
 *
 * Usage:
 *   npm run dev
 *   Then type your request, e.g.:
 *   "Check my balance and buy internet access from the demo server"
 */

import "dotenv/config";
import Anthropic from "@anthropic-ai/sdk";
import * as readline from "readline";
import { AGENT_TOOLS } from "./tools.js";
import { processToolCall } from "../tools/dispatch.js";

const client = new Anthropic();

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


type Message = Anthropic.MessageParam;

async function runAgent(userMessage: string, history: Message[]): Promise<Message[]> {
  const messages: Message[] = [...history, { role: "user", content: userMessage }];

  console.log("\n🤖 ArepaAgent thinking...\n");

  // Agentic loop
  while (true) {
    const response = await client.messages.create({
      model: "claude-sonnet-4-6",
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      tools: AGENT_TOOLS,
      messages,
    });

    messages.push({ role: "assistant", content: response.content });

    if (response.stop_reason === "end_turn") {
      // Print final text response
      const text = response.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("\n");
      if (text) console.log(`\n💬 ${text}\n`);
      break;
    }

    if (response.stop_reason === "tool_use") {
      const toolResults: Anthropic.ToolResultBlockParam[] = [];

      for (const block of response.content) {
        if (block.type !== "tool_use") continue;

        console.log(`\n🔧 Tool: ${block.name}`);
        console.log(`   Input: ${JSON.stringify(block.input)}`);

        const result = await processToolCall(block.name, block.input as Record<string, unknown>);

        console.log(`   Result: ${result.slice(0, 200)}${result.length > 200 ? "..." : ""}`);

        toolResults.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: result,
        });
      }

      messages.push({ role: "user", content: toolResults });
    }
  }

  return messages;
}

// ─── Interactive REPL ─────────────────────────────────────────────────────────
async function main() {
  console.log("┌─────────────────────────────────────────┐");
  console.log("│  🫓  ArepaAgent — x402 Payment Agent     │");
  console.log("│     Avalanche Fuji Testnet               │");
  console.log("└─────────────────────────────────────────┘");
  console.log('\nType your request (e.g. "check my balance") or "exit" to quit.\n');

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let history: Message[] = [];

  const ask = () => {
    rl.question("You: ", async (input) => {
      const trimmed = input.trim();
      if (!trimmed || trimmed.toLowerCase() === "exit") {
        console.log("Hasta luego! 🫓");
        rl.close();
        return;
      }
      history = await runAgent(trimmed, history);
      ask();
    });
  };

  ask();
}

main().catch(console.error);
