// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { Pushh } from "src/Pushh.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract PushhTest is Test {
    Pushh push;
    address owner = makeAddr("owner");
    address minter = makeAddr("minter");
    address holder = makeAddr("holder");
    address user = makeAddr("user");
    uint256 initialSupply = 10_000_000_000e18;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        vm.warp(99);
        address _proxy = Upgrades.deployTransparentProxy(
            "Pushh.sol", owner, abi.encodeCall(Pushh.initialize, (owner, minter, holder))
        );
        push = Pushh(_proxy);
    }

    function test_Init() external {
        assertEq(push.totalSupply(), initialSupply);
        assertTrue(push.hasRole(MINTER_ROLE, minter));
        assertEq(push.balanceOf(holder), initialSupply);
        assertEq(push.YearToTotalSupply(0), initialSupply);
        assertEq(push.YearToTotalSupply(1), initialSupply + (initialSupply * 700) / 10_000);
    }

    function test_Revert_Minting() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, owner, MINTER_ROLE)
        );
        vm.prank(owner);
        push.mint(owner, 100_000e18);

        vm.expectRevert("Invalid Year");
        vm.prank(minter);
        push.mint(holder, 1000e18);
    }

    function testMinting() external {
        uint256 mintable = push.YearToTotalSupply(1) - push.totalSupply();

        //Mint half amount in the starting of next year
        vm.warp(block.timestamp + 365 days);
        vm.prank(minter);
        push.mint(holder, mintable / 2);

        assertEq(push.balanceOf(holder), initialSupply + mintable / 2);
        assertEq(push.totalSupply(), initialSupply + mintable / 2);

        // mint half the amount towards middle of the year
        vm.warp(block.timestamp + 150 days);
        vm.prank(minter);
        push.mint(holder, mintable - mintable / 2);

        assertEq(push.balanceOf(holder), initialSupply + mintable);
        assertEq(push.totalSupply(), push.YearToTotalSupply(1));

        vm.expectRevert("Limit Exceed");
        vm.prank(minter);
        push.mint(holder, 1);
    }
}
