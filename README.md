# ArepaAgent — Autonomous x402 Payment & Arbitrage Agent

Agente autonomo Web3 para el ecosistema **ArepaPay L1** en Avalanche. Implementa el **protocolo x402** (HTTP 402 Payment Required) y arbitraje automatico de liquidez. Cumple con el Track 4 del Hackathon Avalanche Venezuela.

**Track:** _"Build an autonomous AI agent (ERC-8004) that uses the x402 HTTP payment protocol to pay per API call on-chain, unlocking real-world services without human intervention"_

---

## Que hace ArepaAgent

```
┌─────────────────────────────────────────────────────────────────┐
│                         AREPAAGENT                              │
│                                                                 │
│  x402 CLIENT                  ARBITRAGE ENGINE                  │
│  ──────────                   ───────────────                   │
│  GET /api/bcv-rate             monitor ArepaHub rate            │
│       ↓ (HTTP 402)             vs external (BCV/Binance)        │
│  auto-pay via                  ↓ spread > 3%                    │
│  PaymentProcessor              execute cycle                    │
│       ↓                        inject profits → ArepaHub        │
│  retry + X-Payment header                                       │
│       ↓ (200 OK + data)       WIFI VOUCHERS                     │
│  data unlocked                ───────────────                   │
│                               activate() on-chain               │
│                               → ActivationRequested event       │
│                               → MikroTik opens portal           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stack

| Componente | Tecnologia |
|------------|-----------|
| AI Agent | Claude claude-sonnet-4-6 (Anthropic SDK) |
| Blockchain | ethers.js v6 + ArepaPay L1 (Chain ID 13370) |
| x402 Client | HTTP 402 → auto-pay → retry |
| x402 Server | Express middleware con validacion on-chain |
| Contratos | 11 contratos ArepaPay L1 |

---

## Contratos ArepaPay L1 (Chain ID 13370)

| Contrato | Direccion | Proposito |
|----------|-----------|-----------|
| MockUSDT (6 dec) | `0x49FCa1a7E942bd8B76781731df4b13E730AEa8A0` | Token de pago |
| MerchantRegistry | `0xd9c61D113720D5EFe38f159c248F2D05cc5a9d69` | Whitelist comercios |
| PaymentProcessor | `0x2F0280384457CCF427E53ED762Df93a1d1a13AB8` | Motor de pagos |
| RewardTicket | `0x29D720D6b5837f2b9d66834246635a4d8BC00d18` | Tickets de rifa |
| Raffle | `0x252148C81c16ab7f7ec59521E9524b94bfe0e29c` | Rifa 3 ganadores |
| InternetVoucher | `0x6ACC6A8e1146137976eA8ae1043F0D4A8273C1F9` | Minutos WiFi |
| SavingsVault | `0xCf939a5A6da5D022f2231DCE65DCaCd7Aeac1c46` | sUSDT con yield |
| MerchantCreditPool | `0xc09b059534D779f500B94f0DdC677765eEb5674b` | Microcredito |
| RevenueDistributor | `0x7E9f6077c092b20f3b4475aE3253AC1791C7e7b0` | Fees → premios/devs |
| ArepaHub | `0x53E5Bc401Ffc07a083643f57700526Ea716334F1` | Liquidez Bs↔USDT |
| OTCMarket | `0x67b3a03cb0518bb3CB0D33e9951ba2764Cb2b4FE` | P2P escrow |

---

## Setup

```bash
cp .env.example .env
# Editar .env:
#   PRIVATE_KEY=0x... (wallet con USDT en L1)
#   RPC_URL=http://127.0.0.1:9650/ext/bc/24KtPX.../rpc
#   ANTHROPIC_API_KEY=sk-ant-...

npm install
```

## Uso

### Agente interactivo

```bash
npm run dev
```

Ejemplos de comandos:
```
You: check my balance
You: what is the current market spread?
You: run an arbitrage cycle
You: pay panaderia 5 USDT
You: activate 30 minutes of internet
You: fetch http://localhost:3000/api/bcv-rate
You: get me internet access from the demo hotspot
```

### Demo x402 server

```bash
npm run demo
```

Endpoints protegidos con x402:
- `GET /api/bcv-rate` → cuesta **0.10 USDT** → retorna tasa BCV
- `GET /api/internet/open` → cuesta **1.00 USDT** → activa sesion WiFi 30 min

---

## Arquitectura

```
src/
├── agent/
│   ├── index.ts         — REPL + agentic loop (Claude claude-sonnet-4-6)
│   └── tools.ts         — 8 herramientas para Claude
├── blockchain/
│   ├── config.ts        — L1 config: Chain 13370, 11 contratos, USDT 6 dec
│   ├── abis.ts          — ABIs minimos de los 11 contratos
│   └── wallet.ts        — ethers.js provider + wallet desde PRIVATE_KEY
├── tools/
│   ├── checkBalance.ts      — USDT / tickets / minutos
│   ├── payMerchant.ts       — approve() + payMerchant()
│   ├── activateInternet.ts  — InternetVoucher.activate()
│   └── arbitrage.ts         — Arbitraje ArepaHub vs mercado externo
├── x402/
│   ├── types.ts         — Tipos del protocolo x402
│   ├── client.ts        — HTTP 402 → paga → retry
│   └── server.ts        — Express middleware x402
└── demo/
    └── server.ts        — Servidor demo BCV rate + WiFi x402-gated
```

---

## Fee Distribution (RevenueDistributor)

```
Pago de usuario
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

- [ ] ERC-8004 compliant agent identity contract
- [ ] Integracion real Binance P2P API para precios externos
- [ ] MikroTik event listener para InternetVoucher
- [ ] Oracle BCV on-chain como endpoint x402 real
- [ ] CLI flags: `arepa-agent --monitor` (modo headless continuo)
- [ ] Deploy en subnet propia en Fuji (AREPA como gas)
