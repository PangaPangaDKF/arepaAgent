# ArepaAgent

ArepaAgent es un servicio autónomo que corre en segundo plano dentro del ecosistema ArepaPay L1. Los usuarios no lo ven ni lo configuran — simplemente está ahí, reduciendo la fricción de las transacciones entre comerciantes y el protocolo.

Usa x402 para manejar pagos automáticamente, arbitra entre la liquidez interna del protocolo y el mercado externo, y administra el flujo de USDT entre comerciantes y los contratos de ArepaPay.

---

## Setup

```bash
cp .env.example .env
npm install
```

```bash
# .env — wallet (una de las dos)
PRIVATE_KEY=0x...
WDK_SEED=word1 word2 ... word12

# .env — IA (una de las dos, o ninguna para usar npm run cli)
GROQ_API_KEY=gsk_...         # gratis en console.groq.com
ANTHROPIC_API_KEY=sk-ant-...

# .env — red
RPC_URL=http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc
CHAIN_ID=13370
PORT=3001
```

Levanta el servidor demo en una terminal y el agente en otra:

```bash
# Terminal 1
npm run demo

# Terminal 2
npm run dev:groq   # Groq/Llama, gratis
npm run dev        # Claude
npm run cli        # sin IA, comandos directos
```

---

## Comandos

Con el agente IA escribes lo que necesitas:

```
paga 5 a la panaderia
hay oportunidad de arbitraje?
activa 30 minutos de internet
fetch http://localhost:3001/api/bcv-rate
cuál es mi balance?
```

Con el CLI (`npm run cli`):

```
arepa> balance
arepa> pay panaderia 5
arepa> prices
arepa> arbitrage
arepa> internet 30
arepa> fetch http://localhost:3001/api/bcv-rate
```

---

## Contratos en ArepaPay L1

Chain ID 13370 — gas token: AREPA

| Contrato | Dirección |
|----------|-----------|
| ArepaAgent | `0x6352B8D1D72f6B16bb659672d5591fe06aAa41c8` |
| MockUSDT | `0x29D720D6b5837f2b9d66834246635a4d8BC00d18` |
| MerchantRegistry | `0x252148C81c16ab7f7ec59521E9524b94bfe0e29c` |
| PaymentProcessor | `0xc09b059534D779f500B94f0DdC677765eEb5674b` |
| RewardTicket | `0x6ACC6A8e1146137976eA8ae1043F0D4A8273C1F9` |
| Raffle | `0x2F0280384457CCF427E53ED762Df93a1d1a13AB8` |
| InternetVoucher | `0xCf939a5A6da5D022f2231DCE65DCaCd7Aeac1c46` |
| SavingsVault | `0x7E9f6077c092b20f3b4475aE3253AC1791C7e7b0` |
| MerchantCreditPool | `0x53E5Bc401Ffc07a083643f57700526Ea716334F1` |
| RevenueDistributor | `0x67b3a03cb0518bb3CB0D33e9951ba2764Cb2b4FE` |
| ArepaHub | `0xCfEfB29bD69C0af628A1D206c366133629011820` |
| OTCMarket | `0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B` |

Comercios registrados en `MerchantRegistry`: `panaderia`, `botellones`, `perros`, `bodega`.


---

## Pendiente

La activación de internet ya funciona on-chain — el contrato emite `ActivationRequested` con el usuario y los minutos. Lo que falta es el listener del lado del hotspot que intercepte ese evento y abra el portal cautivo en el router MikroTik. El contrato del lado blockchain está listo.

La tasa BCV que usa el agente para comparar con Binance P2P es simulada por ahora. El endpoint x402 `/api/bcv-rate` ya existe y está protegido — conectar datos reales es cuestión de reemplazar la fuente, no de cambiar la arquitectura.
