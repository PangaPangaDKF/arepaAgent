/**
 * Minimal ABIs for ArepaPay contracts — only the functions the agent needs.
 */

export const ERC20_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
] as const;

export const PAYMENT_PROCESSOR_ABI = [
  "function payMerchant(address _merchant, uint256 _amount) external",
  "event PaymentSent(address indexed from, address indexed to, uint256 amount)",
] as const;

export const MERCHANT_REGISTRY_ABI = [
  "function isMerchant(address addr) view returns (bool)",
  "function merchants(address) view returns (string name, address wallet, bool verified)",
] as const;

export const INTERNET_VOUCHER_ABI = [
  "function balanceOf(address user) view returns (uint256)",
  "function activate(uint256 minutes_) external",
  "event ActivationRequested(address indexed user, uint256 amount, uint256 timestamp)",
  "event MinutesMinted(address indexed to, uint256 amount)",
] as const;

export const RAFFLE_ABI = [
  "function isOpen() view returns (bool)",
  "function currentRound() view returns (uint256)",
  "function txCount() view returns (uint256)",
  "function txThreshold() view returns (uint256)",
  "function enter(uint256 amount) external",
  "function stakes(uint256 round, address user) view returns (uint256)",
  "event RaffleOpened(uint256 indexed round, string prize)",
  "event TicketsStaked(uint256 indexed round, address indexed user, uint256 amount)",
] as const;

export const AREPA_HUB_ABI = [
  "function getTotalLiquidity() view returns (uint256)",
  "function getMerchantInfo(address merchant) view returns (uint256 supplied, uint256 earned, uint256 withdrawn, uint256 dailyLimit)",
  "function supplyLiquidity(uint256 amount) external",
  "function buyUSDT(uint256 usdtAmount) external",
  "function sellUSDT(uint256 usdtAmount) external",
  "function currentRate() view returns (uint256)", // BCV rate + margin
  "event LiquiditySupplied(address indexed supplier, uint256 amount)",
  "event USDTBought(address indexed buyer, uint256 usdtAmount, uint256 arepaAmount)",
] as const;

export const OTC_MARKET_ABI = [
  "function createOffer(uint256 usdtAmount, uint256 bsRate) external",
  "function reserveOffer(uint256 offerId) external",
  "function confirmPayment(uint256 offerId) external",
  "function cancelOffer(uint256 offerId) external",
  "function getOffer(uint256 offerId) view returns (address seller, uint256 usdtAmount, uint256 bsRate, uint8 status, address buyer, uint256 reservedAt)",
  "function getActiveOffers() view returns (uint256[])",
  "event OfferCreated(uint256 indexed offerId, address indexed seller, uint256 usdtAmount, uint256 bsRate)",
  "event OfferReserved(uint256 indexed offerId, address indexed buyer)",
  "event OfferCompleted(uint256 indexed offerId)",
] as const;

export const SAVINGS_VAULT_ABI = [
  "function deposit(uint256 usdtAmount) external",
  "function withdraw(uint256 shares) external",
  "function balanceOf(address user) view returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function pricePerShare() view returns (uint256)",
  "event Deposited(address indexed user, uint256 usdt, uint256 shares)",
  "event Withdrawn(address indexed user, uint256 shares, uint256 usdt)",
] as const;

export const REVENUE_DISTRIBUTOR_ABI = [
  "function distribute() external",
  "function pendingDistribution() view returns (uint256)",
  "event Distributed(uint256 toRaffle, uint256 toMerchants, uint256 toDevs, uint256 toReserve)",
] as const;

export const REWARD_TICKET_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function burn(address from, uint256 amount) external",
  "function transfer(address to, uint256 amount) external",
] as const;
