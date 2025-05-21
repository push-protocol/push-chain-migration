// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title MigrationRelease
/// @author Push Chain
/// @notice Allows users to claim their tokens based on a Merkle tree proof
contract MigrationRelease is Ownable {
    event ReleasedInstant(
        address indexed recipient,
        uint indexed amount,
        uint indexed releaseTime
    );
    event ReleasedVested(
        address indexed recipient,
        uint indexed amount,
        uint indexed releaseTime
    );
    event FundsAdded(uint indexed amount, uint indexed timestamp);

    event MerkleRootUpdated(
        bytes32 indexed oldMerkleRoot,
        bytes32 indexed newMerkleRoot
    );

    bytes32 public merkleRoot;

    uint public constant VESTING_PERIOD = 90 days;
    uint public immutable INSTANT_RATIO;
    uint public immutable VESTING_RATIO;

    uint public totalReleased;

    mapping(bytes32 => uint) instantClaimTime;

    mapping(bytes32 => bool) claimedvested;

    constructor(
        address initialOwner,
        uint _instantRatio,
        uint _vestingRatio
    ) Ownable(initialOwner) {
        if (_instantRatio == 0 || _vestingRatio == 0) {
            revert("Invalid Ratio");
        }
        INSTANT_RATIO = _instantRatio;
        VESTING_RATIO = _vestingRatio;
    }

    /// @notice Sets the Merkle root for the contract
    /// @param _merkleRoot The new Merkle root
    /// @dev Only the contract owner can call this function
    /// @dev The function checks if the new Merkle root is valid and not equal to the current root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
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
    function addFunds() external payable onlyOwner {
        // Logic to add funds to the contract
        require(msg.value > 0, "No funds sent");
        emit FundsAdded(msg.value, block.timestamp);
    }

    /// @notice Allows users to release their tokens instantly
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of tokens to release
    /// @param _id The unique identifier for the release
    /// @param _merkleProof The Merkle proof for the recipient
    /// @dev checks if the recipient is whitelisted and has not claimed before
    /// @dev calculates the instant amount based on the INSTANT_RATIO
    /// @dev updates the instantClaimTime mapping and totalReleased variable
    /// @dev transfers the instant amount to the recipient, reverting if the transfer fails
    /// @dev emits a ReleasedInstant event with the recipient address, amount, and release time

    function releaseInstant(
        address _recipient,
        uint _amount,
        uint _id,
        bytes32[] calldata _merkleProof
    ) external {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount, _id));
        require(
            verifyAddress(_recipient, _amount, _id, _merkleProof) &&
                instantClaimTime[leaf] == 0,
            "Not Whitelisted or already Claimed"
        );
        uint instantAmount = _amount * INSTANT_RATIO; //Instantly relaese 5 times the amount

        instantClaimTime[leaf] = block.timestamp;
        totalReleased += instantAmount;
        emit ReleasedInstant(_recipient, instantAmount, block.timestamp);

        transferFunds(_recipient, instantAmount);
    }

    /// @notice Allows users to release their vested tokens
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of tokens to release
    /// @param _id The unique identifier for the release
    /// @dev checks if the recipient is whitelisted and has not claimed before
    /// @dev checks if the vesting period has passed
    /// @dev calculates the vested amount based on the VESTING_RATIO
    /// @dev updates the claimedvested mapping and totalReleased variable
    /// @dev transfers the vested amount to the recipient, reverting if the transfer fails
    /// @dev emits a ReleasedVested event with the recipient address, amount, and release time

    function releaseVested(
        address _recipient,
        uint _amount,
        uint _id
    ) external {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount, _id));
        if (claimedvested[leaf] == true) {
            revert("Already Claimed");
        }

        if (
            instantClaimTime[leaf] == 0 ||
            instantClaimTime[leaf] + VESTING_PERIOD > block.timestamp
        ) {
            revert("Not Whitelisted or Not Vested");
        }

        uint vestedAmount = _amount * VESTING_RATIO; // Vested amount is 10 times the amount
        claimedvested[leaf] = true;
        totalReleased += vestedAmount;
        emit ReleasedVested(_recipient, vestedAmount, block.timestamp);
        transferFunds(_recipient, vestedAmount);
    }

    function transferFunds(
        address _recipient,
        uint _amount
    ) internal {
        if (address(this).balance < _amount) {
            revert("Insufficient balance");
        }
        (bool res, ) = payable(_recipient).call{value: _amount}("");
        require(res, "Transfer failed");
    }

    function verifyAddress(
        address recipient,
        uint amount,
        uint _id,
        bytes32[] calldata _merkleProof
    ) private view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(recipient, amount, _id));
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }
}
