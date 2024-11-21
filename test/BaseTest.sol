// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Pushh } from "src/Pushh.sol";
import { PushGovernor } from "src/mock_helpers/PushGovernor.sol";
import { PushTimelockController, TimelockControllerUpgradeable } from "src/mock_helpers/PushTimelockController.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Test, console } from "forge-std/Test.sol";
import { ProxyAdmin } from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import { PushhV2 } from "src/mock_helpers/PushhV2.sol";
import { Helper } from "test/library.sol";

contract BaseTest is Test {
    error TimelockUnexpectedOperationState(bytes32 operationId, bytes32 expectedStates);

    event Paused(address account);
    event Unpaused(address account);

    Pushh public push;
    PushhV2 public pushV2;
    PushTimelockController public timelock;
    PushGovernor public governor;
    ProxyAdmin proxyAdmin;

    address owner = makeAddr("owner");
    address minter = makeAddr("minter");
    address holder = makeAddr("holder");
    address inflationController = makeAddr("inflationController");
    address user = makeAddr("user");

    uint256 initialSupply = 10_000_000_000e18;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant INFLATION_MANAGER_ROLE = keccak256("INFLATION_MANAGER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    address[] proposers;
    address[] executors;

    function setUp() public virtual {
        vm.warp(99);
        vm.startPrank(owner);
        address futureTimelock = vm.computeCreateAddress(owner, vm.getNonce(owner) + 3);
        address futureGovernor = vm.computeCreateAddress(owner, vm.getNonce(owner) + 5);
        vm.recordLogs();
        push = Pushh(
            Upgrades.deployTransparentProxy(
                "Pushh.sol",
                futureTimelock,
                abi.encodeCall(Pushh.initialize, (owner, minter, inflationController, holder))
            )
        );
        proxyAdmin = ProxyAdmin(Helper.getAdminFromEvents(vm.getRecordedLogs()));

        proposers.push(futureGovernor);
        executors.push(futureGovernor);

        proposers.push(futureTimelock);
        executors.push(futureTimelock);

        console.log(proposers[0], proposers[1]);

        address payable timeProxy = payable(
            Upgrades.deployTransparentProxy(
                "PushTimelockController.sol",
                owner,
                abi.encodeCall(TimelockControllerUpgradeable.initialize, (100, proposers, executors, futureTimelock))
            )
        );

        timelock = PushTimelockController(timeProxy);

        address payable proxy = payable(
            Upgrades.deployTransparentProxy(
                "PushGovernor.sol", owner, abi.encodeCall(PushGovernor.initialize, (push, timelock, 1, 100, 800_000e18))
            )
        );
        governor = PushGovernor(proxy);

        pushV2 = new PushhV2();
    }
}
