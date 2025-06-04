// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationLocker.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title UpgradeLocker
 * @dev Script to upgrade the MigrationLocker contract implementation
 */
contract UpgradeLockerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // Get the proxy and proxy admin addresses from environment variables
        address proxyAddress = vm.envAddress("LOCKER_PROXY_ADDRESS");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        console.log("Upgrading MigrationLocker implementation");
        console.log("Deployer address:", deployerAddress);
        console.log("Proxy address:", proxyAddress);
        console.log("ProxyAdmin address:", proxyAdminAddress);
        
        // Get the ProxyAdmin instance
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        
        // Verify the deployer is the owner of the ProxyAdmin
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the new implementation contract
        MigrationLocker newImplementation = new MigrationLocker();
        console.log("New implementation deployed at:", address(newImplementation));
        
        // Perform the upgrade
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(proxyAddress)),
            address(newImplementation)
        );
        
        console.log("Upgrade completed successfully!");
        
        // Get the current implementation address to confirm the upgrade
        address currentImplementation = proxyAdmin.getProxyImplementation(
            TransparentUpgradeableProxy(payable(proxyAddress))
        );
        
        console.log("Current implementation:", currentImplementation);
        require(
            currentImplementation == address(newImplementation),
            "Upgrade verification failed!"
        );
        
        vm.stopBroadcast();
        
        // Save upgrade information to a file
        string memory upgradeData = vm.toString(block.timestamp);
        upgradeData = string.concat(upgradeData, ",", vm.toString(block.number));
        upgradeData = string.concat(upgradeData, ",", vm.toString(block.chainid));
        upgradeData = string.concat(upgradeData, ",old_implementation,", vm.envOr("OLD_IMPLEMENTATION", string("")));
        upgradeData = string.concat(upgradeData, ",new_implementation,", vm.toString(address(newImplementation)));
        upgradeData = string.concat(upgradeData, ",proxy,", vm.toString(proxyAddress));
        upgradeData = string.concat(upgradeData, ",proxy_admin,", vm.toString(proxyAdminAddress));
        
        // Create the upgrade file
        string memory fileName = string.concat(
            "deployments/locker_upgrade_",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".csv"
        );
        
        vm.writeFile(fileName, upgradeData);
        console.log("Upgrade data saved to:", fileName);
    }
} 