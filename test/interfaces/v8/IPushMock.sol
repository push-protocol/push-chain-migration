// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title IPushMock
 * @dev Minimal interface needed for MigrationLocker contract tests
 */
interface IPushMock {
    function transferFrom(address src, address dst, uint256 rawAmount) external returns (bool);
    function burn(uint256 rawAmount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address dst, uint256 rawAmount) external returns (bool);
}
