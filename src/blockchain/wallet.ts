import { ethers } from "ethers";
import { NETWORK } from "./config.js";

let _provider: ethers.JsonRpcProvider | null = null;
let _wallet: ethers.Wallet | ethers.HDNodeWallet | null = null;

export function getProvider(): ethers.JsonRpcProvider {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(NETWORK.rpcUrl);
  }
  return _provider;
}

/**
 * Returns the agent wallet.
 * Priority: WDK_SEED (BIP-39 mnemonic, WDK-compatible) > PRIVATE_KEY (raw hex)
 *
 * WDK_SEED uses standard BIP-44 derivation (m/44'/60'/0'/0/0) — the same path
 * used by @tetherto/wdk-wallet-evm and all EVM-compatible HD wallets.
 */
export function getWallet(): ethers.Wallet | ethers.HDNodeWallet {
  if (!_wallet) {
    const seed = process.env.WDK_SEED;
    const privateKey = process.env.PRIVATE_KEY;

    if (seed) {
      _wallet = ethers.HDNodeWallet.fromPhrase(seed).connect(getProvider());
    } else if (privateKey) {
      _wallet = new ethers.Wallet(privateKey, getProvider());
    } else {
      throw new Error("Set WDK_SEED (12/24-word mnemonic) or PRIVATE_KEY in .env");
    }
  }
  return _wallet;
}

export async function getAddress(): Promise<string> {
  return getWallet().address;
}

export async function getGasPrice(): Promise<bigint> {
  const feeData = await getProvider().getFeeData();
  return feeData.gasPrice ?? ethers.parseUnits("25", "gwei");
}
