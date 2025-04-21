# Bitcoin-Backed Inheritance Protocol (BBIP)

> **Decentralized, secure, and programmable inheritance management built on Bitcoin via Stacks.**

## Overview

**BBIP** is a Clarity smart contract that enables decentralized and automated inheritance management using the security and finality of Bitcoin through the **Stacks Layer 2**. It ensures inheritance distribution is transparent, tamper-proof, and enforceable through smart contract logic — replacing trust with verifiable code.

## Key Features

- **Multi-oracle death verification** using threshold signatures  
- **Time-locked asset release** for controlled inheritance access  
- **Inheritance tax** collection for contract sustainability  
- **NFT inheritance support** for native tokenized assets  
- **Phased inheritance disbursement** to reduce risk  
- **Dispute resolution system** with on-chain voting  
- **Full Bitcoin compliance** via the **Stacks blockchain**

## Contract Architecture

### Contract Variables

- `contract-owner`: Owner of the contract (typically the will initiator)
- `oracles`: Authorized oracles to confirm death
- `beneficiaries`: Users entitled to inheritance, with metadata
- `nft-ownership`: Tracks NFT ownership upon claim
- `inheritance-phases`: Optional phased distribution configuration
- `disputes`: Raised disputes with evidence hashes
- `death-confirmed`: Flag to activate inheritance claims
- `last-will-hash`: Secure fingerprint of a will document
- `inheritance-tax`: Fixed tax rate for upkeep (default: 2%)

## Functional Modules

### Contract Initialization

- `initialize-contract(oracle-list)`  
  Adds a list of oracle addresses to manage death verification. Only callable by the contract owner.

### Beneficiary Management

- `add-beneficiary(beneficiary, share, lock-period, nft-list)`  
  Registers a beneficiary with a share percentage, time-lock, and NFT allocations.

- `update-will-hash(new-hash)`  
  Updates the hash of the legal will. Ensures off-chain will compliance.

### Death Confirmation

- `confirm-death()`  
  Oracles confirm death. Once required confirmations are met, inheritance distribution becomes available.

- `update-required-confirmations(new-count)`  
  Modifies the number of oracle confirmations needed to verify death.

### Inheritance Distribution

- `claim-inheritance()`  
  Allows eligible beneficiaries to claim their share and NFTs after time-lock expiration and death confirmation.

- `claim-phase-1()`  
  Claims the first phase of a split inheritance for better risk management.

### Dispute Resolution

- `raise-dispute(evidence-hash)`  
  Raises a dispute against the inheritance process with hashed evidence.

- `resolve-dispute(disputer)`  
  Marks the dispute as resolved. Internal process controlled by contract logic.

### Emergency Controls

- `deactivate-contract()`  
  Disables all beneficiary modifications. Used in emergency or legacy transition cases.

## Read-Only Accessors

- `get-beneficiary-info(beneficiary)`  
  Returns beneficiary metadata and claim status.

- `get-contract-status()`  
  Returns global status including death confirmation, confirmations required, and tax rate.

- `get-nft-owner(token-id)`  
  Retrieves the current owner of a specific inherited NFT.

## Validation and Safety

- All inputs are validated:
  - Principal addresses must not be zero or contract address
  - NFT token IDs must be > 0
  - Lock periods must be greater than zero
  - Shares must not exceed 100%
- Custom error codes for precise failure detection
- Strong immutability rules after activation (`is-active` flag)

## Technical Specs

| Feature                | Value                             |
|------------------------|-----------------------------------|
| Language               | Clarity                           |
| Chain                  | Stacks Layer 2                    |
| Bitcoin Compatibility  | ✅ Native Bitcoin settlement      |
| NFT Support            | ✅ Static token allocation        |
| Governance             | Multi-oracle, contract owner      |
| Security               | Time-locks, dispute tracking      |
| Tax Logic              | 2% deducted from beneficiary share|

## Example Use Case

> Alice sets up BBIP, adds three beneficiaries with time-locks and NFT allocations. She adds 3 trusted oracles. Upon her passing, 2 out of 3 oracles confirm the death. After the time-locks expire, the beneficiaries claim their STX and NFTs, with an optional phase-1/phase-2 payout structure. A dispute is raised but resolved via the on-chain vote threshold.

## Integration

- Built for modular use with **Stacks apps**, wallets, and inheritance-focused dApps
- Off-chain components can verify and display on-chain beneficiary data
- NFT compatibility allows seamless handover of collectibles, land, or metaverse items

## Security Notes

- Ensure oracle selection is diverse and trustworthy
- Maintain off-chain copies of wills and hashes
- Encourage phased release and dispute mechanisms for high-value estates

## Contact & Contributions

We welcome audits, reviews, and contributions! For feature proposals or bug reports, please open an issue or contact the protocol maintainers.