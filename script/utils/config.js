/**
 * Configuration for event fetching and merkle proof generation
 */

// MigrationLocker contract configuration
const LOCKER_CONFIG = {
  CONTRACT_ADDRESS: "",
  ABI: [
    "event Locked(address caller, address recipient, uint256 amount)"
  ],
  START_BLOCK: 0, // Block number where to start fetching events from ( DON't MARK THIS AS ZERO)
};

// Output configuration
const OUTPUT_CONFIG = {
  CLAIMS_PATH: "../../output/migration-list.json"
};

module.exports = {
  LOCKER_CONFIG,
  OUTPUT_CONFIG
}; 