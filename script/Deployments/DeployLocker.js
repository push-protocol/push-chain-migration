const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const TOKEN_ADDRESS = "0x37c779a1564DCc0e3914aB130e0e787d93e21804"; // PUSH Token

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Deploy MigrationLocker
  const Locker = await ethers.getContractFactory("MigrationLocker");
  const locker = await Locker.deploy(TOKEN_ADDRESS, deployer.address);
  await locker.waitForDeployment();
  console.log("MigrationLocker deployed at:", await locker.getAddress());
}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
