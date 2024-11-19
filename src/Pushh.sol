// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

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
    uint256 public maxMintCap;

    ///@dev used to determine the time frame for minting
    uint256 public minimumMintInterval;
    uint256 public nextMint;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant INFLATION_MANAGER_ROLE = keccak256("INFLATION_MANAGER_ROLE ");

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

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minterRole);
        _grantRole(INFLATION_MANAGER_ROLE, inflationManager);

        maxMintCap = 700;
        minimumMintInterval = 365 days;
        nextMint = block.timestamp + minimumMintInterval;

        _mint(recipient, 10_000_000_000 * 10 ** decimals());
    }

    function setMaxMintCap(uint256 _maxMint) external onlyRole(INFLATION_MANAGER_ROLE) whenNotPaused {
        maxMintCap = _maxMint;
    }

    /**
     * @dev only Minter can call
     *      reverts if an year has not passed
     *      if 1 year has passed, fetches the mintable year for current Year
     *      The amount + totalSupply should not exceed inflation rate
     *      Sets the mintable amount for next year, if not already set
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        if (amount > (totalSupply() * maxMintCap) / 10_000 || block.timestamp < nextMint) {
            revert("Pushh: Mint exceeds");
        }

        nextMint = block.timestamp + minimumMintInterval;
        _mint(to, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
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
