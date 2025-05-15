const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Deploy MigrationRelease
  const Release = await ethers.getContractFactory("MigrationRelease");
  const release = await Release.deploy(deployer.address);
  await release.waitForDeployment();
  console.log("MigrationRelease deployed at:", await release.getAddress());

}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
