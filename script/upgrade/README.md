# Contract Upgrade Scripts

This directory contains scripts for upgrading the MigrationLocker and MigrationRelease contracts using the transparent proxy pattern.

## Best Practices for Contract Upgrades

1. **Storage Layout Preservation**: Never modify, remove, or reorder existing storage variables. Only add new variables at the end.
2. **Initialize New Variables**: If adding new variables, initialize them in a separate function that can be called after the upgrade.
3. **Function Selectors**: Maintain the same function signatures. Don't change parameter types or return values of existing functions.
4. **Testing**: Thoroughly test the upgrade on a testnet before deploying to mainnet.
5. **Audit**: Have the upgraded contract audited for security issues.
6. **Governance**: Follow appropriate governance procedures for authorizing upgrades.
7. **Verification**: Always verify that the upgrade was successful.

## Prerequisites

- Foundry installed
- Private key for the ProxyAdmin owner
- Address of the proxy contract
- Address of the ProxyAdmin contract

## Environment Setup

Create a `.env` file with the following variables:

```sh
# Required for both scripts
PRIVATE_KEY=your_private_key_here
PROXY_ADMIN_ADDRESS=address_of_proxy_admin_contract

# For MigrationLocker upgrade
LOCKER_PROXY_ADDRESS=address_of_locker_proxy_contract
OLD_IMPLEMENTATION=current_implementation_address # optional, for record keeping

# For MigrationRelease upgrade
RELEASE_PROXY_ADDRESS=address_of_release_proxy_contract
NEW_MERKLE_ROOT=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef # optional
```

Source the environment variables:

```sh
source .env
```

## Usage

### 1. Upgrade MigrationLocker

```sh
forge script script/upgrade/UpgradeLocker.s.sol:UpgradeLockerScript --rpc-url <RPC_URL> --broadcast --verify
```

### 2. Upgrade MigrationRelease

```sh
forge script script/upgrade/UpgradeRelease.s.sol:UpgradeReleaseScript --rpc-url <RPC_URL> --broadcast --verify
```

To upgrade and update the Merkle root at the same time, include the `NEW_MERKLE_ROOT` environment variable.

## Upgrade Records

Upgrade information is saved to CSV files in the `deployments/` directory with the following format:

- `locker_upgrade_<chain_id>_<timestamp>.csv` - MigrationLocker upgrade
- `release_upgrade_<chain_id>_<timestamp>.csv` - MigrationRelease upgrade

Each file contains:
- Timestamp
- Block number
- Chain ID
- Old implementation address (if provided)
- New implementation address
- Proxy address
- ProxyAdmin address
- Merkle root updated flag (for MigrationRelease only)

## Post-Upgrade Verification

After upgrading, always verify:

1. The implementation address has changed
2. The contract is functioning as expected
3. No storage variables were corrupted
4. New features work as intended

## Troubleshooting

If the upgrade fails, check:

1. The deployer has ownership of the ProxyAdmin
2. The addresses are correct
3. The new implementation is compatible with the proxy's storage layout
4. There are sufficient funds for gas fees 