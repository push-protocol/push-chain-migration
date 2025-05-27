// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IEPNS} from "./Mocks/IPush.sol";

/// @title MigrationLocker
/// @author Push Protocol
/// @notice Allows users to lock their Push tokens for migration

contract MigrationLocker is Initializable, Ownable2StepUpgradeable {

    /// @notice Emitted when a user locks their tokens
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens locked
    /// @param id The unique identifier for the lock
    event Locked(address recipient, uint amount, uint indexed id);

    address public immutable PUSH_TOKEN;

    bool public isMigrationPause;

    uint counter;
    mapping(address => uint) public lockedAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract instead of constructor
    /// @param initialOwner The address of the admin
    function initialize(address initialOwner, address pushToken) public initializer {
        require(initialOwner != address(0), "Invalid owner");
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        PUSH_TOKEN = pushToken;
    }

    modifier onlyUnlocked() {
        if (isMigrationPause) {
            revert("Contract is locked");
        }
        _;
    }

    /// @dev admin can lock the contract
    function setToggleLock() external onlyOwner {
        isMigrationPause = !isMigrationPause;
    }

    /// @notice Allows users to lock their tokens for migration
    /// @param _amount The amount of tokens to lock
    /// @param _recipient The address of the recipient
    /// @dev The recipient address cannot be zero
    /// @dev The function transfers the specified amount of tokens from the user to the contract
    /// @dev Emits a Locked event with the recipient address, amount, and a unique identifier
    /// @dev The function increments the counter to ensure unique identifiers for each lock
    function lock(uint _amount, address _recipient) external onlyUnlocked {
        uint codeLength;
        assembly {
            codeLength := extcodesize(_recipient)
        }
        if (_recipient == address(0) || codeLength > 0) {
            revert("Invalid recipient");
        }
        lockedAmount[msg.sender] += _amount;

        IEPNS(PUSH_TOKEN).transferFrom(msg.sender, address(this), _amount);
        emit Locked(_recipient, _amount, counter++);
    }

    /// @notice Allows the owner to burn a specified amount of tokens
    /// @dev The function can only be called by the contract owner
    /// @param _amount The amount of tokens to burn
    /// @dev The function calls the burn function of the IEPNS contract to burn the specified amount of tokens
    function burn(uint _amount) external onlyOwner onlyUnlocked {
        IEPNS(PUSH_TOKEN).burn(_amount);
    }

    function recoverFunds(
        address _token,
        address _to,
        uint _amount
    ) external onlyOwner onlyUnlocked {
        require(_to != address(0), "Invalid recipient");

        require(
            _amount > 0 && _amount <= IEPNS(_token).balanceOf(address(this)),
            "Invalid amount"
        );
        IEPNS(_token).transfer(_to, _amount);
    }
}
