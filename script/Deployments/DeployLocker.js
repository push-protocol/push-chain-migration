const fs = require("fs");
const path = require("path");
const { ethers, upgrades, network } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deployer:", deployer.address);
  const MigrationLocker = await ethers.getContractFactory("MigrationLocker");

  console.log("Deploying MigrationLocker with transparent proxy...");
  const locker = await upgrades.deployProxy(
    MigrationLocker,
    [deployer.address],
    { kind: "transparent", initializer: "initialize" }
  );
  await locker.waitForDeployment();
  console.log("MigrationLocker proxy deployed to:", locker.target);

}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
