// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Pushh } from "src/Pushh.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployScript is Script {
    Pushh public pushh;
    address owner = makeAddr("owner");
    address minter = makeAddr("minter");
    address holder = makeAddr("holder");
    address user = makeAddr("user");

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        address proxy = Upgrades.deployTransparentProxy(
            "Pushh.sol", owner, abi.encodeCall(Pushh.initialize, (owner, minter, owner, holder))
        );

        vm.stopBroadcast();
    }
}
