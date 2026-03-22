# ArepaPay — Roadmap de Ideas Futuras

> Este archivo documenta funcionalidades planeadas para versiones posteriores al MVP.
> No implementar sin análisis previo de contratos y UX.

---

## 🎟️ Sistema de Cupones / Reclamo de Premios (post-rifa)

**Idea:** Cuando un usuario gana una rifa, el contrato le otorga un NFT o token de cupón
que puede mostrar digitalmente para reclamar el premio físico, y luego "quemar" (burn)
para marcarlo como canjeado. Esto hace el proceso verificable on-chain.

**Flujo propuesto:**
1. `draw()` sortea ganadores → mintea `PrizeCoupon` NFT (ERC721) a cada ganador
2. Ganador abre la app → ve su cupón con nombre del premio y estado (canjeado / sin canjear)
3. Muestra el NFT al comerciante / organizador
4. Organizador (o el owner) llama `burnCoupon(tokenId)` → queda registrado on-chain
5. El NFT desaparece del wallet del ganador

**Contratos necesarios:** `PrizeCoupon.sol` (ERC721 con burn controlado)
**Dificultad:** Media — requiere deploy nuevo, integrar con Raffle.sol

---

## 🎯 Sistema de Misiones (Engagement + Onboarding)

**Idea:** Los usuarios completan misiones y reciben tickets de recompensa o vouchers de internet.
Inspirado en "quests" de protocolos DeFi y plataformas de gaming.

**Misiones propuestas:**

### Misiones Sociales (off-chain verificadas por admin)
| Misión | Recompensa | Verificación |
|--------|-----------|--------------|
| Seguir @ArepaPay en X/Twitter | 2 tickets | Manual / OAuth |
| Hacer un post sobre ArepaPay con #ArepaPay | 5 tickets | Manual |
### Misiones en Avalanche (on-chain verificables)
| Misión | Recompensa | Verificación |
|--------|-----------|--------------|
| Probar otra dApp de Avalanche LATAM | 3 tickets | Submit TX hash |
| Hacer swap en Trader Joe (DEX) | 5 tickets | Verificar evento on-chain |
| Bridgear activos con Core Wallet | 3 tickets | Verificar TX en bridge |
| Comprar un NFT en Joepegs | 5 tickets | Verificar transfer ERC721 |
| Agregar liquidez en Benqi | 8 tickets | Verificar LP token |

### Misiones ArepaPay (on-chain automáticas)
| Misión | Recompensa | Trigger |
|--------|-----------|---------|
| Primer pago en comercio | 5 tickets | PaymentProcessor evento |
| 10 pagos totales | 10 tickets + badge | Counter en contrato |
| Pagar 5 comercios distintos | 15 tickets | Set de addresses |
| Recibir primer pago | 2 tickets | Transfer entrante |

**Contratos necesarios:** `MissionBoard.sol` (registro de misiones, reclamación, prevención de doble claim)
**Frontend:** Pantalla "Misiones" en el bottom nav
**Dificultad:** Alta — requiere sistema de verificación hybrid on/off-chain

---

## 🌐 ArepaSubnet — Red Privada de Pagos

**Idea:** Crear una Avalanche L1 (subnet) propia con modelo de fees similar al bancario, pero con redistribucion total de ganancias al ecosistema.

**Modelo de fees (correcto):**
- Las transacciones NO son gratis — se cobra el mismo % que los bancos venezolanos (~0.5-1.5%)
- Fee cobrado en USDT (no en AREPA)
- La diferencia con un banco: el fee se redistribuye completamente al ecosistema

```
Distribucion del fee por transaccion:
  30% → Validadores de la subnet (seguridad de red)
  30% → Merchant LPs y stakers (recompensa por proveer liquidez)
  40% → Pool de premios (rifas, vouchers, incentivos a usuarios)
```

**AREPA Token — rol en la subnet:**
- Token de staking para validadores y Merchant LPs
- Governance: votar cambios de parametros del protocolo
- DAT: el protocolo recompra AREPA en el mercado con % de los fees de red (presion de demanda organica)
- El gas se paga en USDT, no en AREPA

**Beneficios del modelo:**
- Control total sobre validadores y reglas de la red
- Fees economicos pero no gratis — modelo financiero sostenible
- Comerciantes y stakers reciben retorno por participar
- Usuarios reciben parte del fee como premios y vouchers
- KYC selectivo a nivel de validador sin afectar privacidad del usuario final

**Pasos para implementar:**
1. Adquirir validadores Avalanche (staking minimo)
2. Configurar la subnet con Avalanche-CLI
3. Deployar contratos con el nuevo fee model en USDT
4. Actualizar el frontend para conectar a la nueva chain
5. Distribucion inicial de AREPA para bootstrap de stakers y validadores

**Dificultad:** Muy Alta — requiere infraestructura, validadores y fondos para staking

---

## 📊 Historial de Transacciones

**Idea:** Mostrar el historial de pagos del usuario directamente en la app.
No requiere backend — se leen los eventos del contrato.

**Implementación:**
- Escuchar eventos `Transfer(from, to, value)` en MockUSDT filtrando por address
- Escuchar `PaymentSent(payer, merchant, amount)` en PaymentProcessor
- Mostrar lista con fecha, monto en Bs, destinatario, y TX hash
- Cache en localStorage para no re-fetchear en cada apertura

**Dificultad:** Baja — solo frontend, sin nuevo contrato

---

## 🏪 Onboarding de Comerciantes

**Idea:** Flujo de registro de comerciante directamente desde la app.
Actualmente los comercios se registran manualmente via script del admin.

**Flujo propuesto:**
1. Comerciante toca "Quiero ser comercio verificado"
2. Rellena nombre, emoji, categoría, y confirma su wallet
3. Se envía una solicitud (evento on-chain o form off-chain) al admin
4. Admin aprueba → `MerchantRegistry.register(address, name)` → comercio aparece en el directorio

**Dificultad:** Media — requiere UI + posiblemente panel de admin

---

## 💱 Merchant Liquidity Provider (MLP) — La Rampa de Liquidez

**Idea:** Los comerciantes verificados de ArepaPay actuan como proveedores de liquidez (LPs).
No hay una casa de cambio centralizada — el pool lo mantienen los propios comerciantes de la red.
En Venezuela el USDT y las criptomonedas son de uso libre y legal, por lo que esta operacion
entre participantes privados de una red no tiene restricciones regulatorias.

**Sistema de tres tasas (contexto Venezuela):**
```
Tasa BCV oficial:  400 Bs/$  — referencia del gobierno
Tasa de subasta:   515 Bs/$  — subastas del sistema bancario (DICOM)
Tasa paralela:     620 Bs/$  — mercado informal libre
```

**Ciclo completo del MLP:**

Paso 1 — El comercio acumula USDT
El comercio recibe USDT de sus ventas diarias via PaymentProcessor.
No necesita convertirlo al instante — lo acumula en su wallet.

Paso 2 — El comercio vende USDT al LiquidityManager
Cuando el comercio necesita bolivares (para pagar proveedores, empleados, alquiler),
vende su USDT al LiquidityManager a la tasa de subasta (515 Bs/$).
El volumen que puede vender esta limitado a su historial de ventas verificadas on-chain
(evita manipulacion del pool por parte de actores externos).

Ganancia del comercio: recibe 515 Bs/$ en vez de 400 (BCV oficial) = +28.75% mas VES
sin depender de Binance, Airtm ni casas de cambio informales.

Paso 3 — El Proveedor de Liquidez arbitra con el excedente
El LiquidityManager (o un agente de IA conectado al contrato) opera el USDT recibido:
  → Vende en el mercado paralelo a ~620 Bs/$
  → Margen de arbitraje: (620-515)/515 = ~20% de ganancia
  → Con esa ganancia recompra USDT en el mercado
  → Reinyecta el USDT al pool — el ciclo se financia solo

El agente puede ser un smart contract con logica de orden limite, un bot de IA que
monitorea tasas en tiempo real, o una combinacion de ambos.

Paso 4 — Usuario nuevo accede a USDT desde el pool
Usuario transfiere VES a la cuenta bancaria del MLP verificado (paso off-chain).
LiquidityManager.release() envia USDT al wallet del usuario a una tasa preferencial
(entre BCV y subasta, ej: 450 Bs/$).
El usuario obtiene USDT a 450 Bs/$ vs 620 en el mercado = ahorro del ~27%.

**Contratos necesarios:**
- `LiquidityManager.sol` extendido con: `stake()`, `release()`, `setMerchantCap(address, limit)`
- Oraculo de tasas (BCV + subasta) con actualizacion por multisig o feed externo

**Riesgo:** Bajo — Venezuela permite operaciones con USDT entre privados libremente
**Dificultad:** Alta — requiere oracle de tasas, logica de caps por comercio, agente de arbitraje

---

## 📱 PWA con Notificaciones Push

**Idea:** Enviar notificación al usuario cuando recibe un pago, cuando su rifa gana,
o cuando se abre una nueva rifa.

**Implementación:**
- Service Worker + Web Push API
- Backend ligero (Vercel Edge Functions) para escuchar eventos on-chain y disparar notificaciones
- El usuario otorga permiso la primera vez que abre la app

**Dificultad:** Media — requiere backend mínimo

---

*Última actualización: Marzo 2026*
*Estado del MVP actual: Pagos P2P + Rifas + Internet Vouchers + Panel de Comerciante*
