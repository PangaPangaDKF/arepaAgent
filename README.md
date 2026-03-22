# ArepaAgent

Un agente de pagos autónomo construido sobre **ArepaPay L1**, una subnet de Avalanche diseñada para el mercado venezolano. La idea es simple: el agente puede pagar APIs, comercios y servicios on-chain por sí solo, sin que nadie tenga que aprobar cada transacción.

El protocolo que hace esto posible se llama **x402** — cuando el agente hace una petición HTTP a un servicio que cobra, recibe un 402 (Payment Required), paga directamente en la blockchain, y reintenta la llamada con la prueba de pago. Todo en segundos.

---

## Qué puede hacer

**Pagar a comercios locales** — panaderías, bodegas, puestos de comida. Cada pago genera automáticamente un ticket para el raffle mensual y minutos de WiFi gratis.

**Consultar tasas en tiempo real** — conecta con la API pública de Binance P2P para obtener el precio real del USDT en bolívares, y lo compara con la tasa interna del ArepaHub.

**Arbitraje automático** — si detecta una diferencia de precio significativa entre el hub interno y el mercado externo, ejecuta el ciclo y reinvierte la ganancia en el pool de liquidez.

**Activar internet** — llama al contrato `InternetVoucher` on-chain, que emite un evento que un listener puede usar para abrir el portal cautivo de un hotspot real.

**Pagar APIs protegidas** — cualquier endpoint que implemente x402 puede ser pagado automáticamente. El agente maneja todo el flujo sin intervención.

---

## Cómo corre

Hay tres modos según lo que tengas disponible:

```bash
npm run dev:groq   # con IA, usando Groq/Llama (gratis)
npm run dev        # con IA, usando Claude (Anthropic)
npm run cli        # sin IA, comandos directos al contrato
```

Para el servidor de demo que expone las APIs protegidas con x402:

```bash
npm run demo       # corre en el puerto configurado en .env (default 3001)
```

---

## Setup

```bash
cp .env.example .env
npm install
```

En el `.env` necesitas:

```bash
# Wallet — una de las dos
PRIVATE_KEY=0x...
WDK_SEED=word1 word2 ... word12

# IA — una de las dos (o ninguna si usas npm run cli)
GROQ_API_KEY=gsk_...        # gratis en console.groq.com
ANTHROPIC_API_KEY=sk-ant-...

# Red
RPC_URL=http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc
CHAIN_ID=13370
PORT=3001
```

---

## Comandos disponibles

Con el agente IA puedes escribir en lenguaje natural:

```
paga 5 a la panaderia
hay oportunidad de arbitraje?
activa 30 minutos de internet
fetch http://localhost:3001/api/bcv-rate
cuál es mi balance?
```

Con el CLI directo:

```
arepa> balance
arepa> pay panaderia 5
arepa> prices
arepa> arbitrage
arepa> internet 30
arepa> fetch http://localhost:3001/api/bcv-rate
```

---

## Red y contratos

ArepaPay L1 — Chain ID 13370, token de gas: AREPA

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

Comercios registrados en el registry:

| ID | Nombre |
|----|--------|
| `panaderia` | Panaderia El Arepazo |
| `botellones` | Botellones El Mono |
| `perros` | Perros Juancho |
| `bodega` | La Bodega |

---

## Distribución de fees

Cada pago pasa por el `PaymentProcessor` que cobra un 0.03% y lo manda al `RevenueDistributor`:

- 40% al pool del raffle
- 30% al pool de crédito para comerciantes
- 25% al `SavingsVault` (yield para los que depositan)
- 5% reserva

---

## Lo que falta

- Listener real para MikroTik (abrir el captive portal cuando se activa el voucher)
- Oracle BCV on-chain — ahora mismo la tasa BCV es simulada, pero el endpoint x402 ya está listo para conectar con datos reales
- Modo headless: `arepa-agent --monitor` para correr el arbitraje en background sin REPL
