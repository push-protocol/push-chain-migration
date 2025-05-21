// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEPNS} from "./Mocks/IPush.sol";

/// @title MigrationLocker
/// @author Push Chain
/// @notice Allows users to lock their Push tokens for migration
contract MigrationLocker is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a user locks their tokens
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens locked
    /// @param id The unique identifier for the lock
    event Locked(address recipient, uint amount, uint indexed id);

    address public PUSH_TOKEN;

    uint counter;

    constructor(address _push, address _admin) Ownable(_admin) {
        PUSH_TOKEN = _push;
    }

    /// @notice Allows users to lock their tokens for migration
    /// @param _amount The amount of tokens to lock
    /// @param _recipient The address of the recipient
    /// @dev The recipient address cannot be zero
    /// @dev The function transfers the specified amount of tokens from the user to the contract
    /// @dev Emits a Locked event with the recipient address, amount, and a unique identifier
    /// @dev The function increments the counter to ensure unique identifiers for each lock
    function lock(uint _amount, address _recipient) external {
        require(_recipient != address(0), "invalid recipient");
        IERC20(PUSH_TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
        emit Locked(_recipient, _amount, counter++);
    }

    /// @notice Allows the owner to burn a specified amount of tokens
    /// @dev The function can only be called by the contract owner
    /// @param _amount The amount of tokens to burn
    /// @dev The function calls the burn function of the IEPNS contract to burn the specified amount of tokens
    /// @dev Emits a Burn event with the amount burned

    function burn(uint _amount) external onlyOwner {
        IEPNS(PUSH_TOKEN).burn(_amount);
    }
}
