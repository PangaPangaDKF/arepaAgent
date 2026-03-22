# ArepaPay L1 — Plan de Migración y Estado del Desarrollo

> Última actualización: 2026-03-13
> Estado general: **FASE 1 COMPLETADA — FASE 2 EN PROGRESO**

---

## Resumen del Proyecto

Migración de ArepaPay desde Avalanche Fuji Testnet a una L1 soberana personalizada
corriendo localmente en WSL con AvalancheGo v1.14.0 y subnet-evm v0.8.0.

**Regla crítica:** `arepapay-clean/` (MVP en Fuji) jamás se toca. Todo el trabajo va en `arepapay-l1/`.

---

## FASE 1 — Infraestructura L1 ✅ COMPLETADA

### 1.1 Red local
- [x] Crear subnet ArepaPay en WSL con Avalanche CLI
- [x] Arrancar la red con 2 nodos (`NodeID-7Xhw2m...`, `NodeID-MFrZFV...`)
- [x] Chain ID: **13370** | RPC: `http://127.0.0.1:9650/ext/bc/24KtPX.../rpc`
- [x] Token nativo: **AREPA** (18 decimales)
- [x] Documentado en `LOCAL_NETWORK.md`

### 1.2 Contratos desplegados en L1
- [x] **MockUSDT** — 6 decimales (corregido de 18), 1M supply inicial
- [x] **MerchantRegistry** — con `adminRegisterAndVerify()` para onboarding sin gas de merchant
- [x] **RewardTicket** — tickets de rifa (ERC-20 burnable)
- [x] **Raffle** — 3 ganadores ponderados, threshold configurable
- [x] **InternetVoucher** — minutos de internet, 30 min por pago
- [x] **PaymentProcessor** — procesa pagos USDT, minta tickets + minutos
- [x] **SavingsVault** — ahorro sUSDT (VAEM)
- [x] **MerchantCreditPool** — crédito para comerciantes (VAEM)
- [x] **RevenueDistributor** — distribución de ingresos (VAEM)

Direcciones en `LOCAL_NETWORK.md` y `frontend/src/config/network.js`.

### 1.3 Wiring de contratos (post-deploy via cast)
- [x] `RewardTicket.setPaymentProcessor(PaymentProcessor)` — deploy script
- [x] `Raffle.setPaymentProcessor(PaymentProcessor)` — **fix aplicado 2026-03-13 via cast send**
- [x] `InternetVoucher.setPaymentProcessor(PaymentProcessor)` — **fix aplicado 2026-03-13 via cast send**
- [x] `RevenueDistributor.setDestinations(SavingsVault, MerchantCreditPool)` — deploy script
- [x] `DeployL1.s.sol` actualizado para incluir todo el wiring en futuros re-deploys

### 1.4 Setup inicial (SetupL1.s.sol)
- [x] 4 merchants registrados y verificados (Panadería, Agua, Perros, Bodega)
- [x] 1,000 USDT a cada merchant
- [x] 10,000 USDT adicionales al deployer

---

## FASE 2 — Frontend L1 🔄 EN PROGRESO

### 2.1 Frontend copiado y adaptado
- [x] Frontend copiado de `arepapay-clean` a `arepapay-l1/frontend/`
- [x] `network.js` actualizado: Chain ID 13370, nuevas direcciones, token AREPA
- [x] `useBalances.js` — removido liquidityManager (no existe en L1), USDT 6 decimales
- [x] `SendScreen.jsx` — `parseUnits(amount, 6)` corregido (era 18)
- [x] `App.jsx` — botón "Agregar Red ArepaPay L1" con switch + add network flow
- [x] `Dashboard.jsx` — balance overflow corregido (fontSize reducido para montos grandes)
- [x] `useWallet.js` — `getInjectedProvider()` prefiere `window.avalanche` (Core) sobre `window.ethereum` para evitar conflicto con MetaMask

### 2.2 Transacciones verificadas
- [x] Primer pago end-to-end exitoso en L1
- [x] Ticket de rifa se acredita al pagar ✅
- [x] Minutos de internet se acreditan al pagar ✅ (wiring fix aplicado)
- [x] Contador de pagos para rifa avanza ✅ (wiring fix aplicado)
- [x] Threshold de rifa reducido a **5 pagos** (era 10) para demo/testing

### 2.3 Estado actual de la rifa (on-chain)
- txCount: 3 pagos registrados
- txThreshold: 5 (se abre la rifa al pago #5)
- Faltan: **2 pagos** para abrir la primera rifa en la L1

---

## FASE 3 — Pendiente 🔲

### 3.1 Testing completo del ciclo de rifa
- [ ] Completar los 2 pagos restantes para abrir la rifa
- [ ] Apostar tickets con `enter(amount)`
- [ ] Ejecutar sorteo con `draw()` desde el deployer
- [ ] Verificar ganadores en RafflesScreen

### 3.2 SavingsVault (sUSDT) — UI
- [ ] Implementar pantalla de ahorro en el frontend
  - Depositar USDT → recibir sUSDT
  - Retirar sUSDT → recuperar USDT + intereses
- [ ] Integrar con Dashboard (mostrar saldo sUSDT)

### 3.3 MerchantCreditPool — UI
- [ ] Pantalla de crédito para comerciantes
- [ ] Ver límite de crédito disponible
- [ ] Solicitar y repagar crédito en USDT

### 3.4 Producción en Fuji / L1 soberana
- [ ] Desplegar L1 en Avalanche Fuji Testnet (Sovereign: true, ConvertSubnetToL1Tx)
- [ ] Registrar validadores reales (PoA)
- [ ] Actualizar RPC en `network.js` al endpoint público de Fuji
- [ ] Deploy del frontend en Vercel (URL separada del MVP en Fuji)
- [ ] Actualizar `LOCAL_NETWORK.md` con datos de Fuji

### 3.5 Mejoras pendientes de UX
- [ ] InternetScreen: mostrar historial de activaciones
- [ ] Dashboard: historial de transacciones (opcional)
- [ ] MerchantPanel: mejora visual del QR con logo ArepaPay

---

## Comandos clave (WSL)

```bash
# Iniciar red
~/bin/avalanche network start

# Ejecutar cast send en la L1
/home/panga/.foundry/bin/cast send <CONTRACT> "<SIG>" <ARGS> \
  --rpc-url http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc \
  --private-key 0x0faccdcb96ce0d00d7f5135fe4a82fd0d891c096428fd00b6212ef4c9231e1e2

# Redesplegar contratos (si es necesario)
cd ~/arepapay-l1/contracts
PRIVATE_KEY=0x0faccdcb... forge script script/DeployL1.s.sol \
  --rpc-url http://127.0.0.1:9650/.../rpc --broadcast -vvv

# Re-setup (merchants + USDT)
PRIVATE_KEY=0x0faccdcb... forge script script/SetupL1.s.sol \
  --rpc-url http://127.0.0.1:9650/.../rpc --broadcast -vv

# Iniciar frontend
cd arepapay-l1/frontend && npm run dev  # http://localhost:5174
```

---

## Bugs resueltos

| Bug | Causa raíz | Fix |
|-----|-----------|-----|
| `INVALID_ARGUMENT` al cargar | `liquidityManager` undefined en `useBalances.js` | Removido (no existe en L1) |
| `CALL_EXCEPTION` al pagar | `parseUnits(amount, 18)` en vez de 6 | Corregido en `SendScreen.jsx` |
| Botón "Agregar Red" no hacía nada | chainIdHex uppercase `"0x343A"` + null contract crash | Lowercase hex + fix useBalances |
| Tickets no se acreditaban | `RewardTicket.setPaymentProcessor` nunca llamado | Fix en DeployL1 + cast send |
| Internet minutos en 0 siempre | `InternetVoucher.setPaymentProcessor` nunca llamado | cast send aplicado |
| Contador rifa no avanzaba | `Raffle.setPaymentProcessor` nunca llamado | cast send aplicado |
| Balance USDT desbordaba el cuadro | `fontSize: 36px` con montos grandes (10,000+) | Reducido a 26px + overflow hidden |
| Tx no pasa (aprueba en Core, nada) | MetaMask captura `window.ethereum` antes que Core | `getInjectedProvider()` prefiere `window.avalanche` |
