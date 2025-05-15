// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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

    uint public constant VESTING_PERIOD = 60 days;

    mapping(bytes32 => uint) instantClaimTime;

    mapping(bytes32 => bool) claimedvested;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(merkleRoot, _merkleRoot);
    }

    function addFunds() external payable onlyOwner {
        // Logic to add funds to the contract
        require(msg.value > 0, "No funds sent");
        emit FundsAdded(msg.value, block.timestamp);
    }

    function releaseInstant(
        address _recipient,
        uint _amount,
        uint _id,
        bytes32[] calldata _merkleProof
    ) external onlyOwner {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount,_id));
        require(
            verifyAddress(_recipient, _amount, _id, _merkleProof) &&
                instantClaimTime[leaf] == 0,
            "Not Whitelisted or already Claimed"
        );
        uint instantAmount = _amount * 5; //Instantly relaese 5 times the amount

        instantClaimTime[leaf] = block.timestamp;

        // Logic to release funds instantly
        payable(_recipient).transfer(instantAmount);
        emit ReleasedInstant(_recipient, instantAmount, block.timestamp);
    }

    function releaseVested(
        address _recipient,
        uint _amount,uint _id,
        bytes32[] calldata _merkleProof
    ) external onlyOwner {
        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount,_id));
        require(
            instantClaimTime[leaf] + VESTING_PERIOD < block.timestamp &&
                instantClaimTime[leaf] > 0 &&
                verifyAddress(_recipient, _amount,_id, _merkleProof) &&
                claimedvested[leaf] == false,
            "Not Whitelisted"
        );

        uint vestedAmount = _amount * 10; // Vested amount is 10 times the amount
        claimedvested[leaf] = true;
        // Logic to release vested funds
        payable(_recipient).transfer(vestedAmount);
        emit ReleasedVested(_recipient, vestedAmount, block.timestamp);
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
