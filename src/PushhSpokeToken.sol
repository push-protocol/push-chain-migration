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
import {INttToken} from "@wormhole-foundation/native_token_transfer/interfaces/INttToken.sol";

contract PushhSpokeToken is
    INttToken,
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    PausableUpgradeable
{

    // Errors
    error InvalidArgument();
    error InvalidAccess();

    // Events
    event MintCapSet(uint256 newMintCap);

    // State Variables
    /// @notice address of the minter to ensure compatibility with NTT Hub-and-Spoke Method
    address public minter;

    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert CallerNotMinter(msg.sender);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin
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
            defaultAdmin == address(0)
        ) {
            revert InvalidArgument();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /// NOTE: the `setMinter` method is added for INttToken Interface support.
    /// @notice Sets a new minter address, only callable by the contract owner.
    /// @param newMinter The address of the new minter.
    function setMinter(address newMinter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMinter == address(0)) {
            revert InvalidMinterZeroAddress();
        }
        address previousMinter = minter;
        minter = newMinter;

        emit NewMinter(previousMinter, newMinter);
    }

    /**
     * @notice allows the minter to mint tokens
     * @dev only Minter can call
     *      reverts if an year has not passed
     */
    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
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

    /// @notice A function that will burn tokens held by the `msg.sender`.
    /// @param _value The amount of tokens to be burned.
    function burn(uint256 _value) public override(INttToken, ERC20BurnableUpgradeable) {
        ERC20BurnableUpgradeable.burn(_value);
    }
}
