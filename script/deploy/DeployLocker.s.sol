// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationLocker.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title DeployLocker
 * @dev Deployment script for MigrationLocker contract with transparent proxy pattern
 * This script handles:
 * 1. Deployment of the implementation contract
 * 2. Deployment of the ProxyAdmin for managing upgrades
 * 3. Deployment of the TransparentUpgradeableProxy pointing to the implementation
 * 4. Proper initialization of the contract
 */
contract DeployLockerScript is Script {
    function run() external {
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployerAddress);
        
        MigrationLocker implementation = new MigrationLocker();
        console.log("MigrationLocker implementation deployed at:", address(implementation));
        
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployerAddress);
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        
        bytes memory initData = abi.encodeWithSelector(
            MigrationLocker.initialize.selector,
            deployerAddress // Set deployer as initial owner
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        address proxyAddress = address(proxy);
        console.log("MigrationLocker proxy deployed at:", proxyAddress);
        console.log("For verification, implementation address:", address(implementation));
        console.log("For interaction, use proxy address:", proxyAddress);
        
        vm.stopBroadcast();
        
        string memory deploymentData = vm.toString(block.timestamp);
        deploymentData = string.concat(deploymentData, ",", vm.toString(block.number));
        deploymentData = string.concat(deploymentData, ",", vm.toString(block.chainid));
        deploymentData = string.concat(deploymentData, ",implementation,", vm.toString(address(implementation)));
        deploymentData = string.concat(deploymentData, ",proxy_admin,", vm.toString(address(proxyAdmin)));
        deploymentData = string.concat(deploymentData, ",proxy,", vm.toString(proxyAddress));
        
        string memory fileName = string.concat("deployments/locker_", vm.toString(block.chainid), "_", vm.toString(block.timestamp), ".csv");
        vm.writeFile(fileName, deploymentData);
        console.log("Deployment data saved to:", fileName);
    }
} 