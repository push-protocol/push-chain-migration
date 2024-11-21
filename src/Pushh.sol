// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.22;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable,
    NoncesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

contract Pushh is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    PausableUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor

    ///@dev 700 refers to 7%, to avoid round ups, divide by 10000
    uint256 public MAX_MINT_CAP;
    ///@dev used to determine the time frame for minting
    uint256 public constant MIN_MINT_INTERVAL = 365 days;
    ///@dev used to determine the time frame for next possible minting
    uint256 public nextMint;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant INFLATION_MANAGER_ROLE = keccak256("INFLATION_MANAGER_ROLE");

    // Errors
    error InvalidArgument();
    error InvalidAccess();
    error MaxAmountsExceeded();

    // Events
    event MintCapSet(uint256 newMintCap);

    function initialize(
        address defaultAdmin,
        address minterRole,
        address inflationManager,
        address recipient
    )
        public
        initializer
    {
        __ERC20_init("Pushh", "PSH");
        __ERC20Burnable_init();
        __AccessControl_init();
        __ERC20Permit_init("Pushh");
        __ERC20Votes_init();
        __Pausable_init();

        if (
            defaultAdmin == address(0) || minterRole == address(0) || inflationManager == address(0)
                || recipient == address(0)
        ) {
            revert InvalidArgument();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minterRole);
        _grantRole(INFLATION_MANAGER_ROLE, inflationManager);

        MAX_MINT_CAP = 700;
        nextMint = block.timestamp + MIN_MINT_INTERVAL;

        _mint(recipient, 10_000_000_000 * 10 ** decimals());
    }

    /**
     * @notice allows the inflation manager to set/update the mint cap
     */
    function setMaxMintCap(uint256 _maxMint) external onlyRole(INFLATION_MANAGER_ROLE) whenNotPaused {
        MAX_MINT_CAP = _maxMint;
        emit MintCapSet(_maxMint);
    }

    /**
     * @notice allows the minter to mint tokens
     * @dev only Minter can call
     *      reverts if an year has not passed
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 maxMintableAmount = getMaxMintableAmount();
        if (amount > maxMintableAmount) {
            revert InvalidArgument();
        }
        if (block.timestamp < nextMint) {
            revert InvalidAccess();
        }

        nextMint = block.timestamp + MIN_MINT_INTERVAL;
        _mint(to, amount);
    }

    /**
     * @notice allows the default admin to pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    /**
     * @notice allows the default admin to unpause the contract
     */

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice returns the max mintable amount for the current year
     */
    function getMaxMintableAmount() public view returns (uint256) {
        return (totalSupply() * MAX_MINT_CAP) / 10_000;
    }
    /**
     * @notice returns the time (in seconds) until the next mint
     */

    function timeUntilNextMint() public view returns (uint256) {
        return block.timestamp >= nextMint ? 0 : nextMint - block.timestamp;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}
