/**
 * Network and contract configuration — ArepaPay L1 (local Avalanche subnet)
 * Chain ID 13370 with AREPA as native gas token
 * USDT uses 6 decimals (matching real USDT)
 *
 * Fresh deploy addresses (L1 restarted clean):
 */

export const NETWORK = {
  chainId: 13370,
  chainIdHex: "0x343a",
  name: "ArepaPay L1",
  rpcUrl: process.env.RPC_URL ?? "http://127.0.0.1:9650/ext/bc/24KtPXNgmHT2vVUPK1rx72ykjKwHBdfGrQr5bwJxmuaEBm5Fpx/rpc",
  nativeCurrency: { name: "AREPA", symbol: "AREPA", decimals: 18 },
  deployer: "0x0D1F1B9409FF22E65974784D91D65f5f02d24741",
} as const;

/** Fuji Testnet fallback — used if L1 not running locally */
export const FUJI_NETWORK = {
  chainId: 43113,
  chainIdHex: "0xA869",
  name: "Avalanche Fuji Testnet",
  rpcUrl: "https://api.avax-test.network/ext/bc/C/rpc",
  nativeCurrency: { name: "AVAX", symbol: "AVAX", decimals: 18 },
} as const;

/** ArepaPay L1 contracts — fresh deploy after L1 restart */
export const CONTRACTS = {
  // ── ArepaAgent (NEW — ERC-8004) ───────────────────────────────────────
  arepaAgent:         "0x6352B8D1D72f6B16bb659672d5591fe06aAa41c8",

  // ── Payment Core ─────────────────────────────────────────────────────
  mockUSDT:           "0x29D720D6b5837f2b9d66834246635a4d8BC00d18",  // 6 decimals
  merchantRegistry:   "0x252148C81c16ab7f7ec59521E9524b94bfe0e29c",
  paymentProcessor:   "0xc09b059534D779f500B94f0DdC677765eEb5674b",

  // ── Incentives ───────────────────────────────────────────────────────
  rewardTicket:       "0x6ACC6A8e1146137976eA8ae1043F0D4A8273C1F9",
  raffle:             "0x2F0280384457CCF427E53ED762Df93a1d1a13AB8",
  internetVoucher:    "0xCf939a5A6da5D022f2231DCE65DCaCd7Aeac1c46",

  // ── Ecosystem Pools ───────────────────────────────────────────────────
  savingsVault:       "0x7E9f6077c092b20f3b4475aE3253AC1791C7e7b0",  // sUSDT
  merchantCreditPool: "0x53E5Bc401Ffc07a083643f57700526Ea716334F1",
  revenueDistributor: "0x67b3a03cb0518bb3CB0D33e9951ba2764Cb2b4FE",

  // ── Liquidity ────────────────────────────────────────────────────────
  arepaHub:           "0xCfEfB29bD69C0af628A1D206c366133629011820",
  otcMarket:          "0x53ac07432c22eEe0Ee6cE5c003bf198F4712BC0B",
} as const;

/** USDT uses 6 decimals on L1 (matches real USDT, not 18-decimal test tokens) */
export const USDT_DECIMALS = 6;

export const MERCHANTS = [
  {
    id: "panaderia",
    name: "Panaderia El Arepazo",
    category: "Pan • Cachitos • Cafe",
    address: "0x9bEDc23e74204Ab4507a377ab5B59A7B7265a6c5",
  },
  {
    id: "botellones",
    name: "Botellones El Mono",
    category: "Agua 22L • Delivery",
    address: "0xc79D59463c8Ce68c70De0af83cD5B6c1D0e7d621",
  },
  {
    id: "perros",
    name: "Perros Juancho",
    category: "Comida rapida",
    address: "0xeB484FaA19c87AC4a4CC3cA54BA1af92ED1ffD8A",
  },
  {
    id: "bodega",
    name: "La Bodega",
    category: "Abarrotes • Charcuteria",
    address: "0x07727f673ab7f72a31b44a7f24e5c5ac08bd48c2",
  },
] as const;

/** Protocol fee: 0.03% (3 basis points) — auto-split by RevenueDistributor */
export const PROTOCOL_FEE_BPS = 3;
