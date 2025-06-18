// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationLocker.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title UpgradeLocker
 * @dev Upgrade script for MigrationLocker contract
 * This script handles:
 * 1. Deployment of the new implementation contract
 * 2. Upgrading the proxy to point to the new implementation
 */
contract UpgradeLockerScript is Script {
    // Storage slot for ProxyAdmin in TransparentUpgradeableProxy
    bytes32 constant PROXY_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() external {
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_OWNER");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Get proxy address from environment
        address proxyAddress = 0xEf9898A2476bd7b3801e9D257d4c39279eF1583c;

        vm.startBroadcast(deployerPrivateKey);

        console.log("Upgrading contracts with address:", deployerAddress);
        console.log("Current proxy address:", proxyAddress);

        // Deploy new implementation
        MigrationLocker newImplementation = new MigrationLocker();
        console.log("New MigrationLocker implementation deployed at:", address(newImplementation));

        // Get the proxy admin contract from storage slot
        address proxyAdminAddress = address(uint160(uint256(vm.load(proxyAddress, PROXY_ADMIN_SLOT))));
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        console.log("ProxyAdmin address:", proxyAdminAddress);

        // Upgrade the proxy to point to the new implementation
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(proxyAddress)), address(newImplementation), bytes("")
        );
        console.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();
    }
}
