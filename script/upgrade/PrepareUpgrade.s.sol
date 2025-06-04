// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../../src/MigrationLocker.sol";
import "../../src/MigrationRelease.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title PrepareUpgrade
 * @dev Script to prepare and validate a new implementation contract before upgrading
 * This is useful for complex upgrades to ensure compatibility
 */
contract PrepareUpgradeScript is Script {
    enum ContractType {
        LOCKER,
        RELEASE
    }
    
    function run() external {
        // Determine which contract to prepare for upgrade
        string memory contractTypeStr = vm.envOr("CONTRACT_TYPE", string("LOCKER"));
        ContractType contractType;
        
        if (keccak256(bytes(contractTypeStr)) == keccak256(bytes("LOCKER"))) {
            contractType = ContractType.LOCKER;
            console.log("Preparing upgrade for MigrationLocker");
        } else if (keccak256(bytes(contractTypeStr)) == keccak256(bytes("RELEASE"))) {
            contractType = ContractType.RELEASE;
            console.log("Preparing upgrade for MigrationRelease");
        } else {
            revert("Invalid CONTRACT_TYPE. Use LOCKER or RELEASE");
        }
        
        // Get the proxy and proxy admin addresses from environment variables
        address proxyAddress;
        if (contractType == ContractType.LOCKER) {
            proxyAddress = vm.envAddress("LOCKER_PROXY_ADDRESS");
        } else {
            proxyAddress = vm.envAddress("RELEASE_PROXY_ADDRESS");
        }
        
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        console.log("Proxy address:", proxyAddress);
        console.log("ProxyAdmin address:", proxyAdminAddress);
        
        // Get the ProxyAdmin instance
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        
        // Get the current implementation
        address currentImplementation = proxyAdmin.getProxyImplementation(
            TransparentUpgradeableProxy(payable(proxyAddress))
        );
        console.log("Current implementation:", currentImplementation);
        
        // Deploy a new implementation (but don't upgrade yet)
        vm.startBroadcast();
        address newImplementation;
        
        if (contractType == ContractType.LOCKER) {
            MigrationLocker implementation = new MigrationLocker();
            newImplementation = address(implementation);
        } else {
            MigrationRelease implementation = new MigrationRelease();
            newImplementation = address(implementation);
        }
        
        console.log("New implementation deployed at:", newImplementation);
        
        // For demonstration only - don't actually perform the upgrade
        console.log("Preparation complete. Verify the new implementation before upgrading.");
        console.log("To upgrade, run the appropriate upgrade script with:");
        
        if (contractType == ContractType.LOCKER) {
            console.log("forge script script/upgrade/UpgradeLocker.s.sol --rpc-url <RPC_URL> --broadcast");
            console.log("with LOCKER_PROXY_ADDRESS and PROXY_ADMIN_ADDRESS set correctly");
            console.log("Optionally set OLD_IMPLEMENTATION=" + vm.toString(currentImplementation));
        } else {
            console.log("forge script script/upgrade/UpgradeRelease.s.sol --rpc-url <RPC_URL> --broadcast");
            console.log("with RELEASE_PROXY_ADDRESS and PROXY_ADMIN_ADDRESS set correctly");
            console.log("Optionally set OLD_IMPLEMENTATION=" + vm.toString(currentImplementation));
            console.log("Optionally set NEW_MERKLE_ROOT if you want to update the Merkle root");
        }
        
        vm.stopBroadcast();
        
        // Save preparation information to a file
        string memory prepData = vm.toString(block.timestamp);
        prepData = string.concat(prepData, ",", vm.toString(block.number));
        prepData = string.concat(prepData, ",", vm.toString(block.chainid));
        prepData = string.concat(prepData, ",contract_type,", contractTypeStr);
        prepData = string.concat(prepData, ",current_implementation,", vm.toString(currentImplementation));
        prepData = string.concat(prepData, ",new_implementation,", vm.toString(newImplementation));
        prepData = string.concat(prepData, ",proxy,", vm.toString(proxyAddress));
        
        // Create the preparation file
        string memory contractPrefix = contractType == ContractType.LOCKER ? "locker" : "release";
        string memory fileName = string.concat(
            "deployments/",
            contractPrefix,
            "_upgrade_preparation_",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".csv"
        );
        
        vm.writeFile(fileName, prepData);
        console.log("Preparation data saved to:", fileName);
    }
} 