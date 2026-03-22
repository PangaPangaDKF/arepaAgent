# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev        # Claude agent (requires ANTHROPIC_API_KEY)
npm run dev:groq   # Groq/Llama agent, free (requires GROQ_API_KEY)
npm run cli        # Direct CLI — no AI, no API key needed
npm run demo       # x402 demo server (PORT from .env, default 3001)
npm run build      # Compile TypeScript to dist/
npm start          # Run compiled agent (after build)
```

## Environment

Requires `.env` with either `WDK_SEED` (BIP-39 mnemonic, preferred) or `PRIVATE_KEY` (raw hex), plus `ANTHROPIC_API_KEY`. See `.env.example`.

## Architecture

**Network:** ArepaPay L1, Chain ID 13370, AREPA as native gas token. All contract addresses are in `src/blockchain/config.ts`. USDT uses **6 decimals** throughout (matches real USDT — never 18).

**Agent loop** (`src/agent/index.ts`): Interactive REPL → Claude claude-sonnet-4-6 with tool_use → `processToolCall()` dispatch → tool implementations → result back to Claude. No streaming; full agentic loop with history.

**Tool definitions** (`src/agent/tools.ts`): 8 tools declared for Claude — `check_balance`, `pay_merchant`, `activate_internet`, `get_market_prices`, `get_hub_liquidity`, `execute_arbitrage`, `inject_liquidity`, `fetch_with_payment`.

**Tool implementations** (`src/tools/`):
- `payMerchant.ts` — `approve()` + `payMerchant()` on PaymentProcessor; auto-mints raffle ticket + 30 WiFi minutes
- `arbitrage.ts` — Live USDT/VES rate from Binance P2P public API; compares with ArepaHub internal rate
- `checkBalance.ts` — USDT, AVAX, RewardTicket, InternetVoucher balances
- `activateInternet.ts` — Emits `ActivationRequested` event; off-chain listener opens captive portal

**x402 protocol** (`src/x402/`):
- `client.ts` — HTTP 402 → `payMerchant()` on-chain → retry with `X-Payment: <txHash>` header
- `server.ts` — Express middleware; validates tx hash via `PaymentProcessor` ABI `PaymentSent` event; replay-proof via Set
- Our x402 is L1-native (approve+payMerchant). **Do not replace with WDK x402 client** — WDK uses EIP-3009 `transferWithAuthorization` which MockUSDT does not implement.

**Wallet** (`src/blockchain/wallet.ts`): `getWallet()` returns `ethers.HDNodeWallet` (from `WDK_SEED`) or `ethers.Wallet` (from `PRIVATE_KEY`). Both implement the ethers Signer interface identically. WDK seed uses BIP-44 path `m/44'/60'/0'/0/0`.

**Contracts** (`src/blockchain/abis.ts`): Minimal ABIs only. Full ABIs live in `contracts/out/` (Forge artifacts).

## Key Constraints

- USDT decimals: always `USDT_DECIMALS = 6` from config — never hardcode 18
- Gas token: AREPA (not AVAX) on L1; use `ethers.parseUnits("25", "gwei")` as gas fallback
- `ArepaAgent.sol` at `0x6352B8D1D72f6B16bb659672d5591fe06aAa41c8` implements ERC-8004 with daily budget and nonce-based replay protection
- Contract deploys use Forge (`contracts/` directory): `forge script script/DeployArepaAgent.s.sol --rpc-url ... --private-key ... --broadcast`
