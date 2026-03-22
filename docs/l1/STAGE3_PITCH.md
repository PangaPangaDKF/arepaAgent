# ArepaPay — Stage 3 Pitch Answers

## 1. Product Vision
ArepaPay is building the financial rails for the informal Venezuelan economy. In 3 years we see ourselves as the dominant P2P payment network in Venezuela, where local merchants act as trusted USDT liquidity bridges for their communities. Long-term, we become the layer that connects the unbanked Venezuelan population to stable digital money — starting with payments, expanding to savings, micro-credit for merchants, and a self-sustaining ecosystem where every bolivar that enters the network stays and circulates as USDT. ArepaPay integrates the x402 HTTP payment protocol, enabling machine-to-machine micropayments — automated WiFi access, merchant APIs, and AI-driven liquidity agents that reinject arbitrage profits back into the network on Avalanche C-Chain.

---

## 2. Milestones & Roadmap

**Period: Completed**
- Built and launched ArepaPay MVP on Avalanche Fuji Testnet with full payment flow
- Deployed 9 smart contracts: PaymentProcessor, RewardTicket, Raffle (weighted 3-winner draw), InternetVoucher, SavingsVault, MerchantCreditPool, RevenueDistributor
- Migrated to a dedicated Avalanche L1 (ArepaPay subnet, Chain ID 13370) with custom AREPA gas token
- Key deliverable: First real on-chain payment executed on ArepaPay L1 with ticket + internet minute rewards minted automatically

**Period: Q2 2026**
- Deploy OTCMarket contract: local merchant acts as USDT liquidity bridge (user pays cash Bs → merchant confirms → USDT released on-chain via escrow)
- Deploy ArepaHub: admin injects 1,000 USDT initial liquidity, supplies merchants, tracks deposit/withdrawal limits
- Build frontend screens for the full USDT buy/sell flow
- Onboard first 4 real merchants in a pilot barrio
- Key deliverable: Full economic cycle live — user buys USDT from merchant in person, pays other merchants, earns raffle tickets

**Period: Q3 2026**
- 50+ active users in pilot zone
- Raffle prize pool self-funded by network fees (ice cream, moto rides, ice blocks)
- RevenueDistributor live: fees auto-split 40% prizes / 30% merchants / 25% devs / 5% reserve
- Mobile UX improvements (Core Wallet / MetaMask Mobile deep links)
- Key deliverable: Network sustains its own prize pool with zero external funding

**Period: Q4 2026**
- Second merchant cohort onboarded with their own liquidity
- AI arbitrage agent live: buys USDT externally, injects 5% profit back into network
- x402 HTTP payment protocol integration: automated WiFi hotspot payments (InternetVoucher), merchant API monetization, and AI-to-AI micropayments on Avalanche C-Chain
- 500+ active users
- Key deliverable: Public ArepaPay L1 deployed (not local) — real users on mainnet

**Period: 2027**
- Multi-city expansion: Caracas, Maracaibo, Valencia
- Merchant credit pool active: micro-loans backed by on-chain transaction history
- Open liquidity: any verified merchant can become a USDT provider
- Key deliverable: Self-sustaining decentralized P2P payment network across Venezuela

---

## 3. User Acquisition Strategy

**Primary channel: merchants as acquisition agents.**
Each onboarded merchant is a distribution point — they bring their existing customer base into ArepaPay. A bodega owner with 100 daily customers is worth more than any paid ad.

**Secondary channels:**
- In-app incentives: Raffles with real local prizes create organic word-of-mouth
- X/Twitter: Short demos showing instant ArepaPay QR payment vs. slow P2P Binance
- Community referrals: user brings a friend, both earn bonus raffle tickets
- Merchant onboarding fee waiver: first merchants pay zero fees for 3 months

---

## 4. Community Strategy

**Phase 1:** WhatsApp groups per barrio/zona. Each merchant group has a community coordinator. Updates, prize announcements, and new features go through there.

**Phase 2:** X/Twitter presence documenting real stories — "Doña Carmen just won a bag of ice for her 10th payment this month."

**Phase 3:** Merchant Council — merchants vote on raffle prizes, fee adjustments, and which new merchants to onboard.

**Governance (future):** On-chain vote weighted by transaction volume.

---

## 5. Revenue & Sustainability Model

**1.5% fee on every USDT transaction processed through PaymentProcessor.**

Fee distribution (on-chain via RevenueDistributor):
- 40% → Prize & Incentive Pool (helados, hielo, moto rides)
- 30% → Merchant Reward Pool (proportional to volume)
- 25% → Dev & Infrastructure Fund
- 5% → Emergency Reserve

**Secondary revenue: Admin liquidity spread.**
Admin buys USDT externally → sells to merchants at BCV rate + 2-3% margin → spread reinvested into network.

**AI Arbitrage Agent:** Operates external to the network, generates ~5% profit per USDT purchased from merchants, injects all profit back as network liquidity.

**Sustainability math:**
- 500 tx/month × 5 USDT avg = 2,500 USDT volume → ~37.5 USDT fees/month (seed stage)
- 5,000 tx/month × 5 USDT avg = 25,000 USDT volume → ~375 USDT fees/month (growth stage)

---

## 6. Competitive Landscape

**Binance P2P / Airtm** — Larger user base but requires KYC, slow settlement (5-30 min), no incentives, not designed for in-person micro-transactions. ArepaPay: seconds, QR, rewards every payment.

**Reserve (RSV)** — Similar stablecoin thesis in Venezuela/Argentina but global protocol, no local merchant tooling, no community prizes, no dedicated L1.

**Zelle (informal use in Venezuela)** — Widely used but requires a US bank account, excludes most Venezuelans, zero incentives, no blockchain transparency.

**ArepaPay's edge:** The only solution combining instant USDT payments + local merchant liquidity bridges + real hyperlocal rewards (not tokens — actual goods) on a dedicated L1 with near-zero gas costs.
