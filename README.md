# HyperBoreBridge

## Overview

HyperBoreBridge is a cross-chain bridge contract that enables **secure USDC transfers between Ethereum-compatible blockchains and Solana**. It employs **multi-signature validation**, **nonce protection**, and **replay attack prevention** to ensure safe and efficient cross-chain transactions.

### Features

- **Multi-Signature Validation** – Requires a minimum number of validator signatures for transaction approval.
- **Nonce Protection** – Prevents duplicate transactions from being processed.
- **Replay Attack Prevention** – Uses chain-specific hashing to prevent cross-chain signature replay.
- **Fee Collection** – Charges a basis point fee on transfers, directed to the treasury.
- **Two-Step Ownership Transfer** – Protects against accidental contract control loss.
- **Pausable Contract** – Allows emergency contract suspension when needed.
- **Cross-Chain Bridging** – Supports Ethereum-to-Solana and Solana-to-Ethereum USDC transfers.

---

## Deployment

The contract is deployed with:

- An initial validator address.
- A required number of validator signatures.
- The USDC token contract address.
- A fee percentage set in basis points (100 BPS = 1%).

Once deployed, the owner can manage contract settings, validators, and fees.

---

## Contract Functions

### **1. Depositing USDC to Bridge to Solana**

```solidity
function bridgeToSolana(uint256 amount, bytes32 solanaRecipient) external whenNotPaused nonReentrant {}
```

Users send USDC to the contract, specifying a Solana recipient. The deposit is logged with a unique nonce to ensure it is processed only once. A percentage-based fee is deducted before the transfer.

### **2. Releasing USDC from the Bridge (Solana to EVM)**

```solidity
function bridgeFromSolana(
        address recipient,
        uint256 amount,
        bytes32 solanaTransactionId,
        bytes32 nonce,
        Signature[] calldata signatures
    ) external whenNotPaused nonReentrant
```

When a deposit is confirmed on Solana, validators must sign an authorization to release USDC to an Ethereum address. Once the required signatures are collected, the bridge contract processes the withdrawal and sends the funds.

### **3. Administrative Functions**

- **Managing Validators** – The owner can add and remove validators.
- **Updating Required Signatures** – Adjusts the number of validator approvals needed for releases.
- **Updating Fees** – Modifies the fee percentage, with a maximum cap of 20%.
- **Updating Token Address** – Allows the owner to set a new USDC contract address if needed.
- **Pausing & Unpausing** – Lets the owner disable or resume operations in case of security risks.
- **Two-Step Ownership Transfer** – Ensures safe handover of contract ownership.
- **Withdrawing USDC** – Allows the owner to recover contract-held USDC.

---

## Events

The contract emits events for key actions, including:

- **USDC Deposits** – When funds are sent to the bridge for Solana.
- **Token Releases** – When USDC is withdrawn on Ethereum after validator approval.
- **Validator Changes** – When a validator is added or removed.
- **Fee Updates** – When the bridge fee is modified.
- **Token Address Updates** – When the USDC contract address is changed.

---

## Security Features

- **Multi-Signature Verification** – Transactions must be validated by multiple approved signers.
- **Nonce Management** – Ensures each transfer request is unique and cannot be duplicated.
- **Replay Protection** – Uses blockchain-specific signatures to prevent malicious reuse.
- **Reentrancy Protection** – Prevents recursive transaction exploits.
- **Emergency Pausing** – Allows the contract to be paused in case of attacks or vulnerabilities.

---

## Notes

This contract is optimized for **security, efficiency, and flexibility**. While it allows full fund withdrawals when necessary, it is designed to maintain integrity through its **multi-signature system, robust nonce handling, and replay attack prevention**.

If using this contract in a production environment, ensure that all validators are **trusted entities**, and regularly monitor contract events for anomalies.

---

## License

This project is licensed under the MIT License. Please remix it for your own needs and make beautiful, co-operative things.

## Sponsorship

This project is sponsored by [HyperBoreDAO](https://www.hyperboredao.ai/)
