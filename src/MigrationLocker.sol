// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IPUSH } from "./interfaces/IPUSH.sol";

/// @title MigrationLocker
/// @author Push Chain
/// @notice Allows users to lock their Push tokens for migration
contract MigrationLocker is Initializable, Ownable2StepUpgradeable, PausableUpgradeable {
    /// @notice Emitted when a user locks their tokens
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens locked
    event Locked(address caller, address recipient, uint256 amount);

    address public constant PUSH_TOKEN = 0xf418588522d5dd018b425E472991E52EBBeEEEEE;

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
    /// @dev Emits a Locked event with the recipient address, amount, and a unique identifier
    function lock(uint256 _amount, address _recipient) external whenNotPaused {
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(_recipient)
        }
        if (_recipient == address(0) || codeLength > 0) {
            revert("Invalid recipient");
        }

        IPUSH(PUSH_TOKEN).transferFrom(msg.sender, address(this), _amount);
        emit Locked(msg.sender, _recipient, _amount);
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
