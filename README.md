# PUSH Token Migration System

This project implements a secure, two-phase token migration system for the PUSH token ecosystem, enabling users to migrate from the existing PUSH token to a new implementation. The project is built using Solidity and Foundry, with transparent upgradeable proxies for future extensibility.

## Details on Migration
The migration of tokens is from:
- **Old Token:** ERC20 Push Token on Ethereum [@0xf418588522d5dd018b425e472991e52ebbeeeeee](https://etherscan.io/token/0xf418588522d5dd018b425e472991e52ebbeeeeee)
- **New Token:** Native $PUSH Token on Push Chain. ( *Push Chain is a EVM-Compatible chain on Cosmos with a native token called PUSH*)

**Migration Amounts**
- Token migration is planned to be at a 1:15 ratio (1 Push Protocol token = 15 Push Chain tokens).
- The token holders on Ethereum will be required to lock their token in the `MigrationLocker` contract.
- The token holders will be able to release/claim their migrated tokens using the `MigrationRelease` contract on Push Chain.
- The release of tokens will be a two phase release:
a. **Instant Release:** Allows users to claim 50% of their migrated tokens ( 7.5 out of 15 ratio ) instantly.
b. **Vested Release:** Allows users to claim the remaininig 50% of their migrated token 90 days after the instant release.

**Migration Proofs**
- The verification of token locked is done using Merkle Proofs.
- When users lock their tokens, an event emission occurs which is recorded offchain.
- These emissions are then used to generate proofs for each deposit by a given address.
- Users can use these proofs later on Push Chain's `MigrationRelease` contract to claim their migration tokens.

---

## System Architecture

The migration system consists of two main components:

1. **MigrationLocker**: A contract that allows users to lock their PUSH tokens for migration. *To Deployed on Ethereum Mainnet*
2. **MigrationRelease**: A contract that enables whitelisted users to claim their migrated tokens in two phases. *To Deployed on Push Mainnet*

### Technical Stack

- **Solidity**: ^0.8.20
- **Framework**: Foundry, with Hardhat for deployments
- **Proxy Pattern**: OpenZeppelin Transparent Upgradeable Proxy
- **Verification Mechanism**: Merkle Tree for secure, gas-efficient verification
- **Security**: OpenZeppelin contract libraries

## Contract Details

### MigrationLocker.sol

The MigrationLocker contract is responsible for allowing users to lock their PUSH tokens as part of the migration process.

**Key Features:**
- Token locking mechanism with unique identifier generation
- Safety toggles to prevent/allow locking
- Proper access control with Ownable2Step pattern
- Token burning capability for migrated tokens
- Emergency fund recovery functionality

**Main Functions:**
- `lock(uint _amount, address _recipient)`: Allows users to lock tokens for migration
- `burn(uint _amount)`: Burns tokens that have been successfully migrated
- `setToggleLock()`: Toggles whether the contract is accepting new locks
- `recoverFunds(address _token, address _to, uint _amount)`: Emergency function to recover funds

**Events:**
- `Locked(address recipient, uint amount, uint indexed id)`: Emitted when tokens are locked

### MigrationRelease.sol

The MigrationRelease contract manages the release of migrated tokens to eligible users based on Merkle proofs.

**Key Features:**
- Two-phase token release (instant + vested)
- Merkle Tree-based verification for gas efficiency
- Fixed allocation ratios for instant and vested portions
- Fair and transparent distribution mechanism
- Fund recovery safety mechanism

## Important Constants

- `VESTING_PERIOD`: 90 days
- `INSTANT_RATIO`: 75 (interpreted as 7.5x)
- `VESTING_RATIO`: 75 (interpreted as 7.5x)

**Release Model:**
- **Instant Release**: 50% of the locked amount is immediately available
- **Vested Release**: Additional 50% of the locked amount is available after a 90-day vesting period
- Total migration ratio: 1:15 (locked:received)

**Main Functions:**
- `releaseInstant(address _recipient, uint _amount, uint _id, bytes32[] calldata _merkleProof)`: Claims instant portion
- `releaseVested(address _recipient, uint _amount, uint _id)`: Claims vested portion after vesting period
- `setMerkleRoot(bytes32 _merkleRoot)`: Updates the Merkle root for verification
- `addFunds()`: Adds funds to the contract for distribution
- `recoverFunds(address _token, address _to, uint _amount)`: Emergency function to recover funds

**Events:**
- `ReleasedInstant(address indexed recipient, uint indexed amount, uint indexed releaseTime)`
- `ReleasedVested(address indexed recipient, uint indexed amount, uint indexed releaseTime)`
- `FundsAdded(uint indexed amount, uint indexed timestamp)`
- `MerkleRootUpdated(bytes32 indexed oldMerkleRoot, bytes32 indexed newMerkleRoot)`

## Merkle Tree Implementation

The system uses a Merkle Tree for efficient and secure verification of eligible claims. This approach significantly reduces gas costs compared to on-chain storage of all claims.

### Merkle Tree Generation Process

1. Events are collected from the MigrationLocker contract using `fetchAndStoreEvents.js`
2. Each lock event produces a leaf in the Merkle Tree with `(address, amount, id)` as parameters
3. The Merkle root is calculated and set in the MigrationRelease contract
4. Users can provide proofs to verify their eligibility when claiming tokens

### Technical Implementation

The Merkle Tree implementation in `script/utils/merkle.js` provides these key functions:

- `hashLeaf(address, amount, id)`: Creates hashed leaves for the Merkle Tree
- `getRoot(claims)`: Generates the Merkle root from an array of claims
- `getProof(address, amount, id, claims)`: Generates a Merkle proof for a specific claim
- `verify(address, amount, id, claims)`: Verifies a claim against the Merkle Tree

## Security Considerations

### Claims Verification

The system uses the following security measures for claims verification:

1. **Double-claim prevention**: Both instant and vested claims track their status in mappings
2. **Tamper-proof verification**: Merkle Tree verification ensures users can only claim their allocated amounts
3. **Parameter binding**: The address, amount, and ID must all match the Merkle proof
4. **Contract locking**: MigrationLocker can be locked to prevent new tokens from being locked

### Access Control

- Both contracts use OpenZeppelin's `Ownable2StepUpgradeable` for secure ownership management
- Critical functions are protected with `onlyOwner` modifier
- The MigrationLocker can be toggled between locked and unlocked states

### Deployment Scripts

- `script/Deployments/DeployLocker.js`: Deploys the MigrationLocker contract
- `script/Deployments/DeployRelease.js`: Deploys the MigrationRelease contract and sets the Merkle root

## Utility Scripts

The project includes several utility scripts for managing the migration process:

- `script/utils/fetchAndStoreEvents.js`: Fetches lock events from the MigrationLocker contract
- `script/utils/merkle.js`: Contains functions for Merkle Tree generation and verification
- `script/utils/getRoot.js`: Computes the Merkle root from claims data
- `script/utils/getPoof.js`: Generates proofs for individual claims
- `script/utils/verify.js`: Verifies claims against the Merkle Tree
- `script/utils/proofArray.js`: Generates proofs for multiple claims

## Usage Instructions

### Building the Project

```shell
npx hardhat compile
```

### Testing the Project

```shell
npx hardhat test
```

### Test dry run on testnet
Deploying and locking on sepolia
```shell
npx hardhat run script/TestRuns/DeployAndRunOnSepolia.js --network sepolia 
```

Fetching the events from sepolia
```shell
npx hardhat run script/utils/fetchAndStoreEvents.js --network sepolia
```

Once fetched, deploy on local Push chain (Push chain should be running, and the account should have funds)
```shell
npx hardhat run script/Deployments/DeployRelease.js --network pushlocalnet 
```

Update address in `ClaimTokensOnPush.js` and run. 

```shell
npx hardhat run script/TestRuns/ClaimTokensOnPush.js  --network pushlocalnet
```

### Deploying

```shell
npx hardhat run script/Deployments/DeployLocker.js
npx hardhat run script/Deployments/DeployRelease.js
```

### Generating Merkle Root

After users have locked their tokens:

```shell
node script/utils/fetchAndStoreEvents.js
```


```shell
node script/utils/getRoot.js 
```
---

## License

This project is licensed under the MIT License with Attribution - see the [LICENSE](LICENSE) file for details.

Any use of this code must include visible attribution to Push Protocol (https://push.org).

