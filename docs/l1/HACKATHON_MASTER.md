# ArepaPay — Master Hackathon Brief
> Generado: 2026-03-20 | Para uso en hackathons, pitches, y desarrollo del agente AI

---

## 1. Qué es ArepaPay (en 30 segundos)

ArepaPay es una red de pagos P2P construida en una Avalanche L1 dedicada, diseñada para el mercado venezolano. Resuelve el problema de que comprar USDT es caro, lento y requiere confianza en extraños, mientras que hacer pagos digitales pequeños es imposible sin acceso bancario. Los comerciantes locales actúan como puentes de liquidez verificados: el usuario les paga Bolívares en efectivo y recibe USDT on-chain en segundos.

**Stack:**
- Frontend: React 19 + Vite + ethers.js v6
- Contratos: Solidity (Foundry / Forge)
- Red: Avalanche L1 local (Chain ID 13370, AREPA gas token)
- Wallet: Core Wallet / MetaMask
- Infraestructura: AvalancheGo v1.14.0 + subnet-evm v0.8.0 en WSL Ubuntu

---

## 2. Infraestructura actual (todo deployado y funcionando)

### Red ArepaPay L1
| Campo | Valor |
|---|---|
| RPC | `http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc` |
| Chain ID | 13370 |
| Gas Token | AREPA |
| Validación | Proof of Authority (PoA) |
| Deployer | `0x0D1F1B9409FF22E65974784D91D65f5f02d24741` |

### Contratos deployados (11 contratos)
| Contrato | Dirección | Función |
|---|---|---|
| MockUSDT | `0x49FCa1a7E942bd8B76781731df4b13E730AEa8A0` | Stablecoin de prueba (6 decimals) |
| MerchantRegistry | `0xd9c61D113720D5EFe38f159c248F2D05cc5a9d69` | Registro y verificación de merchants |
| RewardTicket | `0x29D720D6b5837f2b9d66834246635a4d8BC00d18` | ERC20 de tickets de rifa |
| Raffle | `0x252148C81c16ab7f7ec59521E9524b94bfe0e29c` | Rifa ponderada, 3 ganadores, threshold=5 |
| InternetVoucher | `0x6ACC6A8e1146137976eA8ae1043F0D4A8273C1F9` | Minutos de WiFi por pago |
| PaymentProcessor | `0x2F0280384457CCF427E53ED762Df93a1d1a13AB8` | Núcleo de pagos USDT |
| SavingsVault | `0xCf939a5A6da5D022f2231DCE65DCaCd7Aeac1c46` | Depósito de USDT con interés |
| MerchantCreditPool | `0xc09b059534D779f500B94f0DdC677765eEb5674b` | Crédito para merchants |
| RevenueDistributor | `0x7E9f6077c092b20f3b4475aE3253AC1791C7e7b0` | Split de fees: 40/30/25/5 |
| ArepaHub | `0x53E5Bc401Ffc07a083643f57700526Ea716334F1` | Admin liquidity hub, precio BCV, límites |
| OTCMarket | `0x67b3a03cb0518bb3CB0D33e9951ba2764Cb2b4FE` | Escrow P2P Bs↔USDT con timeout 30min |

### Flujo económico completo
```
Admin (tú) → inyecta 1,000 USDT → ArepaHub
ArepaHub → vende USDT a merchant @ BCV+2%
Merchant → lista USDT en OTCMarket
Usuario → reserva USDT, paga Bs en efectivo al merchant
Merchant → confirma → OTCMarket libera USDT al usuario
Usuario → paga con USDT en PaymentProcessor
PaymentProcessor → cobra 1.5% fee → RevenueDistributor
RevenueDistributor → split: 40% premios / 30% merchants / 25% devs / 5% reserva
Rifa → cada 5 pagos → sorteo automático → 3 ganadores
```

---

## 3. Frontend (pantallas implementadas)

| Pantalla | Función |
|---|---|
| Dashboard | Balance USDT + tickets + historial de pago |
| SendScreen | Enviar USDT a merchants (input en Bs, conversión automática) |
| ReceiveScreen | QR de la wallet para recibir |
| RafflesScreen | Ver rifas activas, apostar tickets, ver ganadores |
| InternetScreen | Vouchers de minutos WiFi |
| MerchantPanel | Panel del comerciante con QR y monto en Bs |
| OTCMarket UI | (pendiente) Comprar USDT del merchant con Bs |
| ArepaHub UI | (pendiente) Panel admin de liquidez |

---

## 4. Modelo económico

### Ingresos
1. **Fee de transacción:** 1.5% por cada pago USDT en PaymentProcessor
2. **Spread de liquidez:** Admin compra USDT a precio externo, vende a merchants al BCV+2-3%
3. **AI Arbitrage Agent:** Opera externamente, compra USDT a merchants al precio de red, vende en mercados externos con ~5% ganancia, reinvierte todo en liquidez

### Distribución de fees (on-chain automática)
- 40% → Pool de premios (helados, hielo, moto rides)
- 30% → Merchant Reward Pool (proporcional a volumen)
- 25% → Dev & Infrastructure Fund
- 5% → Reserva de emergencia

### Sostenibilidad
- 500 tx/mes × 5 USDT = 2,500 USDT volumen → 37.5 USDT/mes en fees (fase semilla)
- 5,000 tx/mes × 5 USDT = 25,000 USDT volumen → 375 USDT/mes (fase crecimiento)
- Premio autofinanciado: 40% × 37.5 = 15 USDT/mes para helados desde el día 1

---

## 5. x402 en ArepaPay

### Qué es x402
El protocolo HTTP 402 ("Payment Required") permite hacer pagos on-chain automáticos como parte del flujo de una petición web. Sin botones, sin pantallas — el cliente firma y paga solo.

```
Cliente HTTP → GET /recurso
Servidor     → 402 Payment Required { amount: 0.05 USDT, address: 0x... }
Cliente      → firma pago on-chain automáticamente
Facilitador  → liquida en Avalanche
Servidor     → acceso concedido
```

### 3 casos de uso en ArepaPay

**Caso 1 — InternetVoucher (WiFi automático)**
El portal cautivo del proveedor de WiFi responde 402 cuando el usuario intenta conectarse. ArepaPay paga automáticamente con USDT del balance. Sin pantalla de voucher, sin botones — paga solo al conectarse.

**Caso 2 — Merchant API**
Un merchant expone su catálogo o endpoint con protección 402. Agentes externos (AI o apps) pagan automáticamente para consultar precios o hacer pedidos. Crea una capa de ingresos pasivos para merchants.

**Caso 3 — AI Arbitrage Agent**
El agente de arbitraje usa x402 para interactuar con servicios financieros externos (exchanges, oracles de precio) sin intervención humana. El ciclo completo es autónomo.

### Implementación en Avalanche
- x402-rs está en Rust → necesita middleware backend (Node.js o Rust)
- Compatible con Avalanche C-Chain (EVM estándar) y con ArepaPay L1
- SDK de JavaScript en desarrollo — para Q4 2026
- Para el hackathon: implementar el facilitador como Node.js backend

### Repositorios oficiales
- https://github.com/x402-rs/x402-rs
- https://build.avax.network/integrations/x402-rs

---

## 6. El Agente AI — Caso de uso para hackathon

### Nombre: ArepaAgent

**Propuesta de valor en una oración:**
Un agente autónomo basado en Claude que monitorea el mercado venezolano de USDT, ejecuta arbitraje externo, y mantiene la liquidez del ecosistema ArepaPay sin intervención humana — usando x402 para pagos automáticos y los contratos de ArepaPay L1 como su capa de liquidación.

### Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                     ArepaAgent                       │
│                  (Claude claude-sonnet-4-6 API)               │
│                                                     │
│  Herramientas disponibles:                          │
│  ├── get_usdt_price()  → oracle de precio BCV       │
│  ├── check_merchant_inventory() → OTCMarket.sol     │
│  ├── buy_usdt_from_merchant() → OTCMarket escrow    │
│  ├── inject_liquidity() → ArepaHub.sol              │
│  ├── check_network_health() → balances, volumen     │
│  └── send_x402_payment() → facilitador x402         │
└─────────────────────────────────────────────────────┘
         ↕ ethers.js                    ↕ HTTP/x402
┌──────────────────┐          ┌─────────────────────┐
│  ArepaPay L1     │          │  Mercados externos  │
│  - ArepaHub.sol  │          │  - Binance P2P      │
│  - OTCMarket.sol │          │  - Reserve          │
│  - PayProcessor  │          │  - BCV oracle       │
└──────────────────┘          └─────────────────────┘
```

### Flujo del agente (paso a paso)

1. **Monitor:** Cada 15 minutos, el agente revisa el precio USDT en mercados externos vs. el precio en ArepaHub
2. **Análisis:** Claude evalúa si hay oportunidad de arbitraje (diferencia > 3%)
3. **Decisión:** Si sí → compra USDT a merchant en OTCMarket (escrow) → vende en mercado externo → reinvierte ganancia en ArepaHub
4. **Alerta:** Si la liquidez de la red cae por debajo del threshold → notifica al admin y sugiere acción
5. **Reporte:** Genera reporte diario de salud de la red (volumen, fees, balance de premios)

### Stack técnico del agente

```javascript
// Herramientas que le das a Claude
const tools = [
  {
    name: "get_network_liquidity",
    description: "Get current USDT liquidity in ArepaHub and OTCMarket",
    // Llama a ArepaHub.getTotalLiquidity() via ethers.js
  },
  {
    name: "get_external_usdt_price",
    description: "Get current USDT/VES price from external market",
    // Llama a API de precio (Binance, LocalBitcoins API, BCV)
  },
  {
    name: "execute_arbitrage",
    description: "Buy USDT from ArepaPay merchant and sell externally",
    // Firma tx en ArepaPay L1 + ejecuta venta externa
  },
  {
    name: "inject_liquidity",
    description: "Inject USDT profit back into ArepaHub",
    // Llama a ArepaHub.supplyLiquidity() con la ganancia
  },
  {
    name: "send_alert",
    description: "Send alert to admin via webhook/Telegram",
  }
]
```

### Por qué es un proyecto de hackathon ganador

1. **Caso de uso real:** No es un toy — resuelve un problema económico real en Venezuela
2. **Integración nativa Avalanche:** Usa una L1 dedicada con contratos propios, no solo tokens en C-Chain
3. **Claude como cerebro:** El agente toma decisiones financieras no triviales (cuándo arbitrar, cuánto inyectar, cómo equilibrar liquidez)
4. **x402 como diferenciador técnico:** Los pagos del agente son automáticos via HTTP — no requieren aprobación manual
5. **Impacto medible:** Cada ciclo de arbitraje aumenta la liquidez disponible para usuarios venezolanos

### Diferenciación del pitch
- No es otro DeFi bot especulativo
- El profit no sale del ecosistema — se reinvierte
- El agente tiene restricciones codificadas: no puede retirar más USDT del que inyectó
- Auditable: cada decisión del agente queda registrada on-chain

---

## 7. Comandos esenciales

### Levantar la red (después de reinicio)
```bash
# En WSL
~/bin/avalanche network start
~/bin/avalanche blockchain deploy ArepaPay --local
```

### Levantar el frontend
```bash
cd /mnt/c/Users/dulbi/arepapay-l1/frontend
npm run dev
# → http://localhost:5173
```

### Compilar y deployar contratos
```bash
cd /mnt/c/Users/dulbi/arepapay-l1/contracts
PRIVATE_KEY=0x0faccdcb... forge script script/DeployL1.s.sol \
  --rpc-url http://127.0.0.1:9650/ext/bc/24KtPX.../rpc \
  --broadcast -vv
```

### Verificar bloque actual
```bash
cast block-number --rpc-url http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc
```

---

## 8. Pendiente para completar el MVP de la L1

| Item | Prioridad | Estado |
|---|---|---|
| Probar pago completo (ticket + voucher + rifa) | 🔴 Crítico | Pendiente |
| OTCMarket UI (comprar USDT del merchant) | 🔴 Fase 3 | Pendiente |
| ArepaHub UI (panel admin de liquidez) | 🟡 Fase 3 | Pendiente |
| ArepaAgent — esqueleto del agente con Claude API | 🟡 Hackathon | Pendiente |
| x402 facilitador Node.js (middleware) | 🟠 Q4 2026 | No iniciado |

---

## 9. Links y referencias

| Recurso | URL |
|---|---|
| GitHub ArepaPay | https://github.com/PangaPangaDKF/arepapay |
| Deploy Vercel (MVP Fuji) | https://frontend-tau-ten-27.vercel.app |
| Avalanche CLI docs | https://build.avax.network |
| x402-rs repo | https://github.com/x402-rs/x402-rs |
| x402 en Avalanche | https://build.avax.network/integrations/x402-rs |
| OpenZeppelin Contracts | https://github.com/OpenZeppelin/openzeppelin-contracts |
| ethers.js v6 | https://docs.ethers.org/v6 |
| Claude API (Anthropic SDK) | https://docs.anthropic.com/claude/reference |

---

## 10. Frases clave para el pitch

> "ArepaPay no es un exchange — es la infraestructura de confianza que le faltaba al mercado P2P venezolano."

> "El comerciante de la esquina ya es tu banco. ArepaPay solo le da las herramientas para serlo legalmente y digitalmente."

> "Cada helado que gana un usuario fue pagado por los fees de la red — sin un centavo externo."

> "ArepaAgent es el primer agente AI que trabaja para mantener una economía local viva, no para especular."
