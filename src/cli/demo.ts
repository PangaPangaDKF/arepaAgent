/**
 * ArepaAgent — Direct CLI Demo (sin IA, sin API key)
 *
 * Llama las herramientas de blockchain directamente desde la línea de comandos.
 * Ideal para verificar que los contratos funcionan sin necesitar ningún servicio externo.
 *
 * Requiere en .env:
 *   WDK_SEED=word1 word2 ... word12   (o PRIVATE_KEY=0x...)
 *
 * Usage:
 *   npm run cli
 *
 * Comandos disponibles:
 *   balance [address]          — Verificar saldos USDT / AREPA / tickets / minutos
 *   pay <merchant_id> <monto>  — Pagar comercio (panaderia|botellones|perros|bodega)
 *   prices [threshold%]        — Comparar tasa ArepaHub vs Binance P2P
 *   liquidity                  — Liquidez total en ArepaHub
 *   arbitrage [capital] [pct]  — Ejecutar ciclo de arbitraje
 *   internet <minutos>         — Activar minutos WiFi on-chain
 *   fetch <url>                — Fetch URL con auto-pago x402
 *   help                       — Mostrar esta ayuda
 *   exit                       — Salir
 */

import "dotenv/config";
import * as readline from "readline";
import { processToolCall } from "../tools/dispatch.js";

function printHelp() {
  console.log(`
Comandos ArepaAgent CLI:
  balance [address]            — Saldos USDT / AREPA / tickets / minutos
  pay <id> <monto>             — Pagar comercio (panaderia|botellones|perros|bodega)
  prices [umbral%]             — Tasa ArepaHub vs Binance P2P en vivo
  liquidity                    — Liquidez en ArepaHub
  arbitrage [capital] [pct]    — Ejecutar arbitraje
  internet <minutos>           — Activar minutos WiFi
  fetch <url>                  — Fetch URL con pago x402 automático
  help                         — Esta ayuda
  exit                         — Salir
`);
}

async function handleCommand(line: string): Promise<void> {
  const parts = line.trim().split(/\s+/);
  const cmd = parts[0]?.toLowerCase();

  if (!cmd) return;

  let toolName: string;
  let toolInput: Record<string, unknown>;

  switch (cmd) {
    case "balance":
      toolName = "check_balance";
      toolInput = parts[1] ? { address: parts[1] } : {};
      break;

    case "pay":
      if (!parts[1] || !parts[2]) {
        console.log("Uso: pay <merchant_id> <monto>  (ej: pay panaderia 5)");
        return;
      }
      toolName = "pay_merchant";
      toolInput = { merchant_id: parts[1], amount_usdt: parts[2] };
      break;

    case "prices":
      toolName = "get_market_prices";
      toolInput = parts[1] ? { spread_threshold_pct: parseFloat(parts[1]) } : {};
      break;

    case "liquidity":
      toolName = "get_hub_liquidity";
      toolInput = {};
      break;

    case "arbitrage":
      toolName = "execute_arbitrage";
      toolInput = {};
      if (parts[1]) toolInput.max_capital_usdt = parts[1];
      if (parts[2]) toolInput.spread_threshold_pct = parseFloat(parts[2]);
      break;

    case "internet":
      if (!parts[1]) {
        console.log("Uso: internet <minutos>  (ej: internet 30)");
        return;
      }
      toolName = "activate_internet";
      toolInput = { minutes: parseInt(parts[1], 10) };
      break;

    case "fetch":
      if (!parts[1]) {
        console.log("Uso: fetch <url>  (ej: fetch http://localhost:3000/api/bcv-rate)");
        return;
      }
      toolName = "fetch_with_payment";
      toolInput = { url: parts[1] };
      break;

    case "help":
      printHelp();
      return;

    case "exit":
    case "quit":
      console.log("Hasta luego! 🫓");
      process.exit(0);

    default:
      console.log(`Comando desconocido: "${cmd}". Escribe "help" para ver los comandos.`);
      return;
  }

  console.log(`\n⚙️  ${toolName} ${JSON.stringify(toolInput)}`);
  const result = await processToolCall(toolName, toolInput);
  try {
    console.log(JSON.stringify(JSON.parse(result), null, 2));
  } catch {
    console.log(result);
  }
  console.log();
}

async function main() {
  console.log("┌──────────────────────────────────────────────┐");
  console.log("│  🫓  ArepaAgent — CLI Demo (sin IA)           │");
  console.log("│     Acceso directo a contratos ArepaPay L1   │");
  console.log("└──────────────────────────────────────────────┘");
  printHelp();

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let closed = false;

  rl.on("close", () => { closed = true; });

  const ask = () => {
    if (closed) return;
    rl.question("arepa> ", async (input) => {
      try {
        await handleCommand(input);
      } catch (err) {
        console.error(`\n❌ Error: ${(err as Error).message}\n`);
      }
      ask();
    });
  };

  ask();
}

main().catch(console.error);
