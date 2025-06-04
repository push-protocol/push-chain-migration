// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationRelease.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title UpgradeRelease
 * @dev Script to upgrade the MigrationRelease contract implementation
 */
contract UpgradeReleaseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // Get the proxy and proxy admin addresses from environment variables
        address proxyAddress = vm.envAddress("RELEASE_PROXY_ADDRESS");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        console.log("Upgrading MigrationRelease implementation");
        console.log("Deployer address:", deployerAddress);
        console.log("Proxy address:", proxyAddress);
        console.log("ProxyAdmin address:", proxyAdminAddress);
        
        // Get the ProxyAdmin instance
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        
        // Verify the deployer is the owner of the ProxyAdmin
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the new implementation contract
        MigrationRelease newImplementation = new MigrationRelease();
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
        
        // Optional: Update the merkle root if provided
        string memory merkleRootStr = vm.envOr("NEW_MERKLE_ROOT", string(""));
        if (bytes(merkleRootStr).length > 0) {
            bytes32 newMerkleRoot = vm.parseBytes32(merkleRootStr);
            if (newMerkleRoot != bytes32(0)) {
                // Access the proxy as a MigrationRelease contract
                MigrationRelease releaseProxy = MigrationRelease(proxyAddress);
                
                // Update the merkle root
                releaseProxy.setMerkleRoot(newMerkleRoot);
                console.log("Updated merkle root to:", vm.toString(newMerkleRoot));
            }
        }
        
        vm.stopBroadcast();
        
        // Save upgrade information to a file
        string memory upgradeData = vm.toString(block.timestamp);
        upgradeData = string.concat(upgradeData, ",", vm.toString(block.number));
        upgradeData = string.concat(upgradeData, ",", vm.toString(block.chainid));
        upgradeData = string.concat(upgradeData, ",old_implementation,", vm.envOr("OLD_IMPLEMENTATION", string("")));
        upgradeData = string.concat(upgradeData, ",new_implementation,", vm.toString(address(newImplementation)));
        upgradeData = string.concat(upgradeData, ",proxy,", vm.toString(proxyAddress));
        upgradeData = string.concat(upgradeData, ",proxy_admin,", vm.toString(proxyAdminAddress));
        
        if (bytes(merkleRootStr).length > 0) {
            upgradeData = string.concat(upgradeData, ",merkle_root_updated,true");
        } else {
            upgradeData = string.concat(upgradeData, ",merkle_root_updated,false");
        }
        
        // Create the upgrade file
        string memory fileName = string.concat(
            "deployments/release_upgrade_",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".csv"
        );
        
        vm.writeFile(fileName, upgradeData);
        console.log("Upgrade data saved to:", fileName);
    }
} 