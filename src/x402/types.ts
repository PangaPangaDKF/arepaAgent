/**
 * x402 Protocol Types
 * HTTP 402 Payment Required — machine-to-machine micropayments
 * Reference: https://x402.org
 */

/** What the server sends in the 402 response body */
export interface X402PaymentRequired {
  scheme: "exact";
  network: string;          // e.g. "evm"
  maxAmountRequired: string; // USDT amount in wei (18 decimals)
  resource: string;          // URL being accessed
  description: string;
  mimeType: string;
  payTo: string;             // Merchant/receiver wallet address
  maxTimeoutSeconds: number;
  asset: string;             // Token contract address (MockUSDT)
  extra?: {
    name?: string;
    version?: string;
  };
}

/** Payment proof the client attaches to the retry request */
export interface X402PaymentHeader {
  scheme: "exact";
  network: string;
  payload: {
    signature: string;   // EIP-712 signed authorization OR tx hash
    authorization: {
      from: string;
      to: string;
      value: string;       // amount in wei
      validAfter: number;  // unix timestamp
      validBefore: number; // unix timestamp (expires)
      nonce: string;
    };
  };
}

export interface X402Response<T> {
  paid: boolean;
  data?: T;
  error?: string;
  paymentRequired?: X402PaymentRequired;
}
