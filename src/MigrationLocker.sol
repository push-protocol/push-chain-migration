// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IPUSH } from "./interfaces/IPush.sol";

/// @title MigrationLocker
/// @author Push Chain
/// @notice Allows users to lock their Push tokens for migration
contract MigrationLocker is Initializable, Ownable2StepUpgradeable, PausableUpgradeable {
    /// @notice Indicates the current epoch
    /// @dev    Each specific epoch represents a particular block of time under which all Locked events will be
    ///         recorded to create the merkle tree all user deposits done in that specific epoch.
    ///         The epoch is owner-controlled and new epoch is initiated via initiateNewEpoch().
    ///         Valid epoch starts from 1.
    uint256 public epoch;
    /// @notice Maps a specific epoch to its start block.
    ///         Read-only state for on-chain, Useful state off-chain for fetching events from the contract.
    mapping(uint256 => uint256) public epochStartBlock;
    /// @notice The address of the PUSH token
    address public constant PUSH_TOKEN = 0xf418588522d5dd018b425E472991E52EBBeEEEEE;

    /**
     * EVENTS and ERRORS ******
     */

    /// @notice Emitted when a user locks their tokens
    /// @param caller The address of the caller
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens locked
    /// @param epoch The epoch number
    event Locked(address caller, address recipient, uint256 amount, uint256 epoch);

    /// @notice Emitted when a admin initiates a new epoch
    event NewEpoch(uint256 indexed epoch, uint256 indexed startBlock);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract instead of constructor
    /// @param initialOwner The address of the admin
    function initialize(address initialOwner) public initializer {
        require(initialOwner != address(0), "Invalid owner");
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        __Pausable_init();

        initiateNewEpoch();
    }

    /// @notice Allows the owner to initiate a new epoch
    /// @dev The function increments the epoch number and sets the start block for the new epoch
    /// @dev Emits a NewEpoch event with the epoch number and start block
    function initiateNewEpoch() public onlyOwner {
        epoch++;
        epochStartBlock[epoch] = block.number;
        emit NewEpoch(epoch, block.number);
    }

    /// Pauseable Features
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Allows users to lock their tokens for migration
    /// @param _amount The amount of tokens to lock
    /// @param _recipient The address of the recipient
    /// @dev The recipient address cannot be zero
    /// @dev The function transfers the specified amount of tokens from the user to the contract
    /// @dev Emits a Locked event with the recipient address, amount, and epoch
    function lock(uint256 _amount, address _recipient) external whenNotPaused {
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(_recipient)
        }
        if (_recipient == address(0) || codeLength > 0) {
            revert("Invalid recipient");
        }

        IPUSH(PUSH_TOKEN).transferFrom(msg.sender, address(this), _amount);
        emit Locked(msg.sender, _recipient, _amount, epoch);
    }

    /// @notice Allows the owner to burn a specified amount of tokens
    /// @dev The function can only be called by the contract owner
    /// @param _amount The amount of tokens to burn
    /// @dev The function calls the burn function of the IPush contract to burn the specified amount of tokens
    function burn(uint256 _amount) external onlyOwner whenNotPaused {
        IPUSH(PUSH_TOKEN).burn(_amount);
    }

    function recoverFunds(address _token, address _to, uint256 _amount) external onlyOwner whenNotPaused {
        require(_to != address(0), "Invalid recipient");

        require(_amount > 0 && _amount <= IPUSH(_token).balanceOf(address(this)), "Invalid amount");
        IPUSH(_token).transfer(_to, _amount);
    }
}
