# ArepaAgent — Autonomous x402 Payment Agent

Agente autónomo Web3 para el ecosistema **ArepaPay L1** en Avalanche. Implementa el **protocolo x402** (HTTP 402 Payment Required) para pagos automáticos on-chain sin intervención humana. Cumple con el **Track 4** del Hackathon Avalanche Venezuela.

> **Track:** *"Build an autonomous AI agent (ERC-8004) that uses the x402 HTTP payment protocol to pay per API call on-chain, unlocking real-world services without human intervention"*

---

## Qué hace

```
Usuario / IA
     │
     ▼
ArepaAgent (ERC-8004)
     │
     ├── x402 CLIENT ──────────────────────────────────────────
     │   GET /api/bcv-rate (API protegida)
     │       ↓ HTTP 402 + { payTo, amount: 0.1 USDT }
     │   ERC20.transfer(payTo, 0.1 USDT) ──► L1 on-chain
     │       ↓ txHash confirmado
     │   Retry GET con X-Payment-TxHash header
     │       ↓ 200 OK + datos desbloqueados
     │
     ├── MERCHANT PAYMENTS ────────────────────────────────────
     │   PaymentProcessor.payMerchant(comercio, USDT)
     │       ↓ automáticamente
     │   + RewardTicket minted (entrada al raffle)
     │   + InternetVoucher minted (30 min WiFi)
     │
     └── ARBITRAGE ENGINE ─────────────────────────────────────
         ArepaHub rate vs Binance P2P (live)
             ↓ spread > 3%
         Ejecuta ciclo → inyecta profits → ArepaHub
```

---

## Stack

| Componente | Tecnología |
|------------|-----------|
| AI Agent | Claude claude-sonnet-4-6 (Anthropic) / llama-3.3-70b (Groq, gratis) |
| Blockchain | ethers.js v6 + ArepaPay L1 (Chain ID 13370) |
| x402 Client | HTTP 402 → auto-pay on-chain → retry con proof header |
| x402 Server | Express middleware con validación de receipt on-chain |
| Contratos | 12 contratos ArepaPay L1 |
| Agent Identity | ERC-8004 `ArepaAgent.sol` |

---

## Contratos ArepaPay L1 (Chain ID 13370)

| Contrato | Dirección | Propósito |
|----------|-----------|-----------|
| ArepaAgent (ERC-8004) | `0x6352B8D1D72f6B16bb659672d5591fe06aAa41c8` | Identidad del agente |
| MockUSDT (6 dec) | `0x29D720D6b5837f2b9d66834246635a4d8BC00d18` | Token de pago |
| MerchantRegistry | `0x252148C81c16ab7f7ec59521E9524b94bfe0e29c` | Whitelist comercios |
| PaymentProcessor | `0xc09b059534D779f500B94f0DdC677765eEb5674b` | Motor de pagos |
| RewardTicket | `0x6ACC6A8e1146137976eA8ae1043F0D4A8273C1F9` | Tickets de rifa |
| Raffle | `0x2F0280384457CCF427E53ED762Df93a1d1a13AB8` | Rifa 3 ganadores |
| InternetVoucher | `0xCf939a5A6da5D022f2231DCE65DCaCd7Aeac1c46` | Minutos WiFi |
| SavingsVault | `0x7E9f6077c092b20f3b4475aE3253AC1791C7e7b0` | sUSDT con yield |
| MerchantCreditPool | `0x53E5Bc401Ffc07a083643f57700526Ea716334F1` | Microcrédito |
| RevenueDistributor | `0x67b3a03cb0518bb3CB0D33e9951ba2764Cb2b4FE` | Fees → premios/devs |
| ArepaHub | `0xCfEfB29bD69C0af628A1D206c366133629011820` | Liquidez Bs↔USDT |
| OTCMarket | `0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B` | P2P escrow |

### Comercios registrados

| ID | Nombre | Dirección |
|----|--------|-----------|
| `panaderia` | Panaderia El Arepazo | `0x9bEDc23e74204Ab4507a377ab5B59A7B7265a6c5` |
| `botellones` | Botellones El Mono | `0xc79d59463C8ce68C70de0aF83CD5B6c1d0e7D621` |
| `perros` | Perros Juancho | `0xeB484faa19c87AC4A4cc3cA54bA1af92ed1fFD8A` |
| `bodega` | La Bodega | `0x07727f673ab7f72a31b44a7f24e5c5ac08bd48c2` |

---

## Setup

```bash
cp .env.example .env
# Editar .env con UNA de estas opciones de wallet:
#   PRIVATE_KEY=0x...              (clave privada hex)
#   WDK_SEED=word1 word2 ... word12 (mnemónica BIP-39)
#
# Y UNA de estas opciones de IA:
#   ANTHROPIC_API_KEY=sk-ant-...   (para npm run dev)
#   GROQ_API_KEY=gsk_...           (para npm run dev:groq — GRATIS)

npm install
```

---

## Uso

### Terminal 1 — Demo server x402

```bash
npm run demo
# Inicia en PORT=3001 (configurar en .env)
```

Endpoints protegidos con x402:
- `GET /api/bcv-rate` → cuesta **0.10 USDT** → retorna tasa BCV
- `GET /api/internet/open` → cuesta **1.00 USDT** → activa sesión WiFi 30 min

### Terminal 2 — Elegir modo de agente

**Con IA (lenguaje natural):**
```bash
npm run dev:groq    # Groq/Llama — gratis, requiere GROQ_API_KEY
npm run dev         # Anthropic/Claude — requiere ANTHROPIC_API_KEY
```

Ejemplos de comandos en lenguaje natural:
```
You: cuál es mi balance?
You: paga 5 USDT a la panaderia
You: hay oportunidad de arbitraje ahora mismo?
You: activa 30 minutos de internet
You: fetch http://localhost:3001/api/bcv-rate
```

**Sin IA (comandos directos, sin API key):**
```bash
npm run cli
```

```
arepa> balance
arepa> pay panaderia 5
arepa> prices
arepa> arbitrage
arepa> internet 30
arepa> fetch http://localhost:3001/api/bcv-rate
arepa> help
```

---

## Arquitectura

```
src/
├── agent/
│   ├── index.ts          — REPL + agentic loop (Claude)
│   ├── index-groq.ts     — Agente Groq/Llama (OpenAI-compatible)
│   └── tools.ts          — 8 herramientas para el LLM
├── blockchain/
│   ├── config.ts         — L1 config: Chain 13370, 12 contratos, USDT 6 dec
│   ├── abis.ts           — ABIs mínimos de todos los contratos
│   └── wallet.ts         — WDK_SEED (BIP-44) o PRIVATE_KEY fallback
├── tools/
│   ├── dispatch.ts       — processToolCall() compartido entre agentes
│   ├── checkBalance.ts   — USDT / AREPA / tickets / minutos
│   ├── payMerchant.ts    — approve() + payMerchant() + recompensas
│   ├── activateInternet.ts — InternetVoucher.activate()
│   └── arbitrage.ts      — Binance P2P live rate + ciclo de arbitraje
├── x402/
│   ├── types.ts          — Tipos del protocolo x402
│   ├── client.ts         — HTTP 402 → paga on-chain → retry con proof
│   └── server.ts         — Middleware Express, valida receipt on-chain
├── cli/
│   └── demo.ts           — REPL directo sin IA
└── demo/
    └── server.ts         — Servidor demo con rutas x402-gated
```

---

## Fee Distribution (RevenueDistributor)

```
Pago del usuario
    ↓
PaymentProcessor (0.03% fee)
    ↓
RevenueDistributor
    ├── 40% → Raffle prize pool (helados, paseos, premios)
    ├── 30% → MerchantCreditPool (rewards por volumen)
    ├── 25% → SavingsVault (yield para depositantes sUSDT)
    └──  5% → Emergency Reserve
```

---

## Roadmap

- [x] ERC-8004 compliant agent identity contract (`ArepaAgent.sol`)
- [x] Integración real Binance P2P API para precios externos (live)
- [x] x402 protocol — client + server con validación on-chain
- [x] Groq/Llama mode (sin costo, sin tarjeta de crédito)
- [x] WDK-compatible wallet (BIP-44 seed phrase)
- [ ] MikroTik event listener para InternetVoucher (captive portal real)
- [ ] Oracle BCV on-chain como endpoint x402 real
- [ ] Deploy en Fuji testnet para acceso público de jueces
- [ ] CLI flags: `arepa-agent --monitor` (modo headless continuo)
