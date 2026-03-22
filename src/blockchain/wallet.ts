import { ethers } from "ethers";
import { NETWORK } from "./config.js";

let _provider: ethers.JsonRpcProvider | null = null;
let _wallet: ethers.Wallet | null = null;

export function getProvider(): ethers.JsonRpcProvider {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(NETWORK.rpcUrl);
  }
  return _provider;
}

export function getWallet(): ethers.Wallet {
  if (!_wallet) {
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) throw new Error("PRIVATE_KEY not set in .env");
    _wallet = new ethers.Wallet(privateKey, getProvider());
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
