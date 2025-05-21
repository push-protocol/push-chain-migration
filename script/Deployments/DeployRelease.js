const fs = require("fs");
const path = require("path");
const { ethers, upgrades } = require("hardhat");
const whitelist = require("../../output/claims.json");
const { getRoot } = require("../utils/merkle");

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Deploy MigrationRelease
  const Release = await ethers.getContractFactory("MigrationRelease");
  const release = await upgrades.deployProxy(Release, [deployer.address], { kind: "transparent", initializer: "initialize" })
  await release.waitForDeployment();
  console.log("MigrationRelease deployed at:", await release.getAddress());

  console.log("creating and updating merkle root");
  const root = getRoot(whitelist);
  console.log("Merkle Root:", root);

  const tx = await release.setMerkleRoot(root);
  await tx.wait();
  console.log("Merkle Root set in contract:", await release.merkleRoot());
}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
