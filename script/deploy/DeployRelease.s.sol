// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationRelease.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";


/**
 * @title DeployRelease
 * @dev Deployment script for MigrationRelease contract with transparent proxy pattern
 */
contract DeployReleaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployerAddress);
        
        MigrationRelease implementation = new MigrationRelease();
        console.log("MigrationRelease implementation deployed at:", address(implementation));
        
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployerAddress);
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        
        bytes memory initData = abi.encodeWithSelector(
            MigrationRelease.initialize.selector,
            deployerAddress // Set deployer as initial owner
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        address proxyAddress = address(proxy);
        console.log("MigrationRelease proxy deployed at:", proxyAddress);
        
        vm.stopBroadcast();
    }
} 