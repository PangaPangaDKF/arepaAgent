# ArepaAgent

Venezuela tiene un problema de infraestructura financiera: las tasas de cambio varían por hora, los comercios pequeños no tienen acceso a sistemas de pago digitales confiables, y el acceso a internet depende de operadores que no tienen ningún incentivo para modernizarse. ArepaPay L1 es una subnet de Avalanche construida para atacar ese problema desde la base — contratos propios, token de gas propio (AREPA), y reglas del ecosistema definidas on-chain.

ArepaAgent es el componente autónomo de ese ecosistema. Un agente que puede pagar, arbitrar y activar servicios por su cuenta, sin que nadie tenga que firmar cada transacción.

---

## El protocolo x402

El núcleo del agente está construido sobre x402 — una extensión del protocolo HTTP donde un servidor responde `402 Payment Required` en lugar de `401 Unauthorized`. El cliente recibe las instrucciones de pago en el cuerpo de la respuesta (a qué dirección, cuánto, en qué token), ejecuta la transacción on-chain, y reintenta la petición con el hash de la transacción como prueba.

El servidor valida el hash consultando el receipt directamente en la blockchain — no hay intermediarios, no hay sesiones, no hay estado compartido. Si el pago está en el bloque, el recurso se entrega.

Esto permite que cualquier API cobre por llamada sin cuentas, sin subscripciones, sin tarjetas. El agente lo maneja automáticamente.

---

## Qué hace en la práctica

Cuando le dices al agente `paga 5 a la panaderia`, ejecuta dos transacciones en secuencia: primero autoriza al `PaymentProcessor` a gastar USDT, luego llama a `payMerchant()`. El contrato transfiere los fondos, mintea un `RewardTicket` (entrada al raffle mensual) y acredita 30 minutos de WiFi en el `InternetVoucher` — todo en la misma transacción.

Cuando le dices `fetch http://localhost:3001/api/bcv-rate`, el agente hace la petición, recibe el 402, paga 0.1 USDT directamente a la wallet del servidor, y reintenta. El servidor verifica el `Transfer` event en el receipt y responde con la tasa.

Cuando le dices `arbitrage`, consulta la tasa interna del `ArepaHub` y la compara con el precio en tiempo real de Binance P2P. Si el spread supera el umbral, ejecuta el ciclo y reinyecta la ganancia al pool de liquidez.

El agente entiende lenguaje natural (via Claude o Groq/Llama) o acepta comandos directos si no tienes API key.

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

## Fees y flujo de valor

El `PaymentProcessor` cobra 0.03% por transacción y lo acumula en el `RevenueDistributor`. Cuando se ejecuta `distribute()`, el contrato reparte: 40% al pool del raffle, 30% al pool de crédito para comerciantes, 25% al `SavingsVault` como yield para los depositantes, y 5% a reserva. La idea es que el volumen de pagos financie directamente los incentivos del ecosistema — rifas, crédito y rendimiento — sin depender de ninguna entidad central.

---

## Pendiente

La activación de internet ya funciona on-chain — el contrato emite `ActivationRequested` con el usuario y los minutos. Lo que falta es el listener del lado del hotspot que intercepte ese evento y abra el portal cautivo en el router MikroTik. El contrato del lado blockchain está listo.

La tasa BCV que usa el agente para comparar con Binance P2P es simulada por ahora. El endpoint x402 `/api/bcv-rate` ya existe y está protegido — conectar datos reales es cuestión de reemplazar la fuente, no de cambiar la arquitectura.
