// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { BaseTest } from "test/BaseTest.sol";
import { console } from "lib/forge-std/src/console.sol";
import { PushhV2 } from "src/mock_helpers/PushhV2.sol";
import { PausableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { Helper } from "test/library.sol";
import { Pushh } from "src/Pushh.sol";

contract PushTest is BaseTest {
    function setUp() public override {
        BaseTest.setUp();
    }

    function test_Init() external view {
        assertEq(push.totalSupply(), initialSupply);
        assertTrue(push.hasRole(MINTER_ROLE, minter));
        assertTrue(push.hasRole(INFLATION_MANAGER_ROLE, inflationController));
        assertEq(push.balanceOf(holder), initialSupply);
    }

    function testPause() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, DEFAULT_ADMIN_ROLE)
        );
        vm.startPrank(minter);
        push.pause();

        vm.expectEmit(true, true, true, true);
        emit Paused(owner);
        vm.startPrank(owner);
        push.pause();
        assertTrue(push.paused());

        uint256 mintable1 = (push.totalSupply() * push.MAX_MINT_CAP()) / 10_000;
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        changePrank(minter);
        push.mint(holder, mintable1);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.startPrank(inflationController);
        push.setMaxMintCap(900);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        push.pause();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, DEFAULT_ADMIN_ROLE)
        );
        vm.startPrank(minter);
        push.unpause();

        vm.expectEmit(true, true, true, true);
        emit Unpaused(owner);
        vm.startPrank(owner);
        push.unpause();
        assertFalse(push.paused());

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector));
        push.unpause();
    }

    function test_Revert_Minting() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, owner, MINTER_ROLE)
        );

        push.mint(owner, 100_000e18);

        vm.expectRevert(abi.encodeWithSelector(Pushh.InvalidAccess.selector));
        changePrank(minter);
        push.mint(holder, 1000e18);
    }

    function testMinting() external {
        uint256 mintable1 = (push.totalSupply() * push.MAX_MINT_CAP()) / 10_000;
        //Mint half amount in the starting of next year
        vm.warp(block.timestamp + 365 days);
        changePrank(minter);
        push.mint(holder, mintable1 / 2);

        assertEq(push.balanceOf(holder), initialSupply + mintable1 / 2, "1");
        assertEq(push.totalSupply(), initialSupply + mintable1 / 2, "2");

        // revert miniting half the amount towards middle of the year
        vm.expectRevert(abi.encodeWithSelector(Pushh.InvalidAccess.selector));
        vm.warp(block.timestamp + 150 days);
        changePrank(minter);
        push.mint(holder, mintable1 - mintable1 / 2);

        uint256 mintable2 = (push.totalSupply() * push.MAX_MINT_CAP()) / 10_000;
        vm.warp(block.timestamp + 215 days);
        push.mint(holder, mintable2);

        assertEq(push.balanceOf(holder), initialSupply + mintable1 / 2 + mintable2, "3");
        assertEq(push.totalSupply(), initialSupply + mintable1 / 2 + mintable2, "4");
    }

    function testMinting_WhenIncreaseLimit() external {
        uint256 mintable1 = (push.totalSupply() * push.MAX_MINT_CAP()) / 10_000;
        assertEq(mintable1, (10_000_000_000e18 * 700) / 10_000);
        //Mint half amount in the starting of next year
        vm.warp(block.timestamp + 365 days);
        vm.startPrank(minter);
        push.mint(holder, mintable1 / 2);

        assertEq(push.balanceOf(holder), initialSupply + mintable1 / 2, "1");
        assertEq(push.totalSupply(), initialSupply + mintable1 / 2, "2");

        vm.startPrank(inflationController);
        push.setMaxMintCap(900);
        uint256 mintable2 = (push.totalSupply() * push.MAX_MINT_CAP()) / 10_000;
        assertEq(mintable2, ((initialSupply + mintable1 / 2) * 900) / 10_000);

        //  miniting after increasing inflation
        vm.warp(block.timestamp + 365 days);
        changePrank(minter);
        push.mint(holder, mintable2);

        assertEq(push.balanceOf(holder), initialSupply + mintable1 / 2 + mintable2, "3");
        assertEq(push.totalSupply(), initialSupply + mintable1 / 2 + mintable2, "4");
    }

    //proposal related variables
    address[] targets;
    uint256[] values;
    bytes _call;
    bytes[] calldatas;
    string description;
    uint256 id;

    function testUpgrade() external {
        //prepare the proposal
        targets.push(address(proxyAdmin));
        values.push(0);
        _call = (abi.encodeWithSelector(proxyAdmin.upgradeAndCall.selector, address(push), address(pushV2), bytes("")));
        calldatas.push(_call);
        description = "Upgrading Push Token";

        //send the proposal
        vm.startPrank(holder);
        push.delegate(holder);
        vm.roll(block.number + 1);
        id = governor.propose(targets, values, calldatas, description);

        //wait for snapshot period then cast vote
        uint256 timePast = governor.proposalSnapshot(id);
        vm.roll(block.number + timePast);
        governor.castVote(id, 1);

        // wait for voting period, then queue
        uint256 deadline = governor.proposalDeadline(id);
        vm.roll(block.number + deadline);
        governor.queue(id);

        //reverts if executed before time
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockUnexpectedOperationState.selector,
                Helper.hashOperationBatch(
                    targets, values, calldatas, bytes32(""), bytes20(address(governor)) ^ keccak256(bytes(description))
                ),
                Helper._encodeStateBitmap(Helper.OperationState.Ready)
            )
        );
        governor.execute(id);

        //wait for timelock delay, then execute
        vm.warp(block.timestamp + 101);
        governor.execute(id);

        //check the upgrade
        pushV2 = PushhV2(address(push));
        assertEq(bytes(pushV2.V2()), bytes("THiS is MOCK V2"));
    }
}
