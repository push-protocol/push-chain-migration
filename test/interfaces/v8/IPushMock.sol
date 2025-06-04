// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title IPushMock
 * @dev Minimal interface needed for MigrationLocker contract tests
 */
interface IPushMock {
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool);
    function burn(uint256 rawAmount) external;
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
} 