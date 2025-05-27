// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

interface IPUSH{
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    event HolderWeightChanged(address indexed holder, uint256 amount, uint weight);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function born() external view returns (uint);
    function holderWeight(address) external view returns (uint);
    function holderDelegation(address, address) external view returns (bool);
    function delegates(address) external view returns (address);
    function checkpoints(address, uint32) external view returns (Checkpoint memory);
    function numCheckpoints(address) external view returns (uint32);
    function nonces(address) external view returns (uint);

    function mint(uint96 _amountToMint) external;
    function allowance(address account, address spender) external view returns (uint);
    function approve(address spender, uint rawAmount) external returns (bool);
    function permit(address owner, address spender, uint rawAmount, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool);
    function returnHolderUnits(address account, uint atBlock) external view returns (uint);
    function returnHolderDelegation(address account, address delegate) external view returns (bool);
    function setHolderDelegation(address delegate, bool value) external;
    function resetHolderWeight(address holder) external;
    function burn(uint256 rawAmount) external;
    function delegate(address delegatee) external;
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external;
    function getCurrentVotes(address account) external view returns (uint96);
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}