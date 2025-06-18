// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MigrationRelease
/// @author Push Chain
/// @notice Allows users to claim their tokens based on a Merkle tree proof
contract MigrationRelease is Initializable, Ownable2StepUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    event ReleasedInstant(address indexed recipient, uint256 indexed amount, uint256 indexed releaseTime);
    event ReleasedVested(address indexed recipient, uint256 indexed amount, uint256 indexed releaseTime);
    event FundsAdded(uint256 indexed amount, uint256 indexed timestamp);

    event MerkleRootUpdated(bytes32 indexed oldMerkleRoot, bytes32 indexed newMerkleRoot);

    bytes32 public merkleRoot;

    uint256 public constant VESTING_PERIOD = 90 days;
    uint256 public constant INSTANT_RATIO = 75;
    uint256 public constant VESTING_RATIO = 75;

    uint256 public totalReleased;
    bool public isClaimPaused;

    mapping(bytes32 => uint256) public instantClaimTime;

    mapping(bytes32 => bool) public claimedvested;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
    }

    /// @dev admin can pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the Merkle root for the contract
    /// @param _merkleRoot The new Merkle root
    /// @dev Only the contract owner can call this function
    /// @dev The function checks if the new Merkle root is valid and not equal to the current root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner whenNotPaused {
        if (_merkleRoot == bytes32(0) || _merkleRoot == merkleRoot) {
            revert("Invalid Merkle Root");
        }
        emit MerkleRootUpdated(merkleRoot, _merkleRoot);
        merkleRoot = _merkleRoot;
    }

    /// @notice Allows the contract owner to add funds to the contract
    /// @dev The function can only be called by the contract owner
    /// @dev The function requires that the amount sent is greater than zero
    /// @dev The function emits a FundsAdded event with the amount and timestamp
    function addFunds() external payable onlyOwner whenNotPaused {
        // Logic to add funds to the contract
        require(msg.value > 0, "No funds sent");
        emit FundsAdded(msg.value, block.timestamp);
    }

    /// @notice Allows users to release their tokens instantly
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of tokens to release
    /// @param _epoch The epoch number
    /// @param _merkleProof The Merkle proof for the recipient
    /// @dev checks if the recipient is whitelisted and has not claimed before
    /// @dev calculates the instant amount based on the INSTANT_RATIO
    /// @dev updates the instantClaimTime mapping and totalReleased variable
    /// @dev transfers the instant amount to the recipient, reverting if the transfer fails
    /// @dev emits a ReleasedInstant event with the recipient address, amount, and release time

    function releaseInstant(
        address _recipient,
        uint256 _amount,
        uint256 _epoch,
        bytes32[] calldata _merkleProof
    )
        external
        whenNotPaused
    {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount, _epoch));
        require(
            verifyAddress(_recipient, _amount, _epoch, _merkleProof) && instantClaimTime[leaf] == 0,
            "Not Whitelisted or already Claimed"
        );
        uint256 instantAmount = (_amount * INSTANT_RATIO) / 10; //Instantly relaese 7.5 times the amount

        instantClaimTime[leaf] = block.timestamp;
        totalReleased += instantAmount;
        emit ReleasedInstant(_recipient, instantAmount, block.timestamp);

        transferFunds(_recipient, instantAmount);
    }

    /// @notice Allows users to release their vested tokens
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of tokens to release
    /// @param _epoch The epoch number
    /// @dev checks if the recipient is whitelisted and has not claimed before
    /// @dev checks if the vesting period has passed
    /// @dev calculates the vested amount based on the VESTING_RATIO
    /// @dev updates the claimedvested mapping and totalReleased variable
    /// @dev transfers the vested amount to the recipient, reverting if the transfer fails
    /// @dev emits a ReleasedVested event with the recipient address, amount, and release time

    function releaseVested(address _recipient, uint256 _amount, uint256 _epoch) external whenNotPaused {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount, _epoch));
        if (claimedvested[leaf] == true) {
            revert("Already Claimed");
        }

        if (instantClaimTime[leaf] == 0 || instantClaimTime[leaf] + VESTING_PERIOD > block.timestamp) {
            revert("Not Whitelisted or Not Vested");
        }

        uint256 vestedAmount = (_amount * VESTING_RATIO) / 10; // Vested amount is 7.5 times the amount
        claimedvested[leaf] = true;
        totalReleased += vestedAmount;
        emit ReleasedVested(_recipient, vestedAmount, block.timestamp);
        transferFunds(_recipient, vestedAmount);
    }

    function transferFunds(address _recipient, uint256 _amount) private {
        if (address(this).balance < _amount) {
            revert("Insufficient balance");
        }
        (bool res,) = payable(_recipient).call{ value: _amount }("");
        require(res, "Transfer failed");
    }

    function verifyAddress(
        address recipient,
        uint256 amount,
        uint256 _epoch,
        bytes32[] calldata _merkleProof
    )
        private
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(recipient, amount, _epoch));
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    function recoverFunds(address _token, address _to, uint256 _amount) external onlyOwner whenNotPaused {
        require(_to != address(0), "Invalid recipient");

        if (_token == address(0)) {
            transferFunds(_to, _amount);
            return;
        } else {
            require(_amount > 0 && _amount <= IERC20(_token).balanceOf(address(this)), "Invalid amount");
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }
}