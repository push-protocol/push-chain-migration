// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IPUSH} from "./Mocks/IPush.sol";

/// @title MigrationLocker
/// @author Push Chain
/// @notice Allows users to lock their Push tokens for migration
contract MigrationLocker is Initializable, Ownable2StepUpgradeable {

    /// @notice Emitted when a user locks their tokens
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens locked
    event Locked(address recipient, uint amount);

    // address public constant PUSH_TOKEN =
    //     0x37c779a1564DCc0e3914aB130e0e787d93e21804;
address public PUSH_TOKEN;

    function setToken(address _token) external {
        PUSH_TOKEN = _token;
    }
    bool public isMigrationPause;

    uint counter;

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

        IPUSH(PUSH_TOKEN).transferFrom(msg.sender, address(this), _amount);
        emit Locked(_recipient, _amount);
    }

    /// @notice Allows the owner to burn a specified amount of tokens
    /// @dev The function can only be called by the contract owner
    /// @param _amount The amount of tokens to burn
    /// @dev The function calls the burn function of the IPUSH contract to burn the specified amount of tokens
    function burn(uint _amount) external onlyOwner onlyUnlocked {
        IPUSH(PUSH_TOKEN).burn(_amount);
    }

    function recoverFunds(
        address _token,
        address _to,
        uint _amount
    ) external onlyOwner onlyUnlocked {
        require(_to != address(0), "Invalid recipient");

        require(
            _amount > 0 && _amount <= IPUSH(_token).balanceOf(address(this)),
            "Invalid amount"
        );
        IPUSH(_token).transfer(_to, _amount);
    }
}
