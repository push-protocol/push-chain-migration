/**
 * Configuration for event fetching and merkle proof generation
 */

// MigrationLocker contract configuration
const LOCKER_CONFIG = {
  CONTRACT_ADDRESS: "",
  ABI: [
    "event Locked(address caller, address recipient, uint256 amount, uint256 epoch)",
    "function epoch() view returns (uint256)",
    "function epochStartBlock(uint256) view returns (uint256)"
  ],
  // Optional: Filter specific epochs (leave empty to process all epochs)
  FILTER_EPOCHS: [] // e.g. [1, 2] to only process epochs 1 and 2
};

// Output configuration
const OUTPUT_CONFIG = {
  CLAIMS_PATH: "../../output/migration-list.json"
};

module.exports = {
  LOCKER_CONFIG,
  OUTPUT_CONFIG
}; 