const fs = require("fs");
const path = require("path");
const { ethers, upgrades, network } = require("hardhat");

async function main() {
  let TOKEN_ADDRESS;
  const [deployer] = await ethers.getSigners();

  
  if (network.name === "mainnet") {
    // Ethereum Mainnet PUSH token
    TOKEN_ADDRESS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE"; // Replace with actual mainnet address
    console.log("Using mainnet PUSH token address");
  } else if (network.name === "sepolia") {
    // Sepolia testnet PUSH token
    TOKEN_ADDRESS = "0x37c779a1564DCc0e3914aB130e0e787d93e21804"; // PUSH Token
    console.log("Using Sepolia testnet PUSH token address");
  } else if (network.name === "hardhat" || network.name === "localhost") {
    // For local development, deploy a mock token
    console.log("Deploying a mock PUSH token for local development");
    const EPNS = await ethers.getContractFactory("EPNS");
    const pushToken = await EPNS.deploy(deployer.address);
    await pushToken.waitForDeployment();
    TOKEN_ADDRESS = await pushToken.getAddress();
  }

  console.log("Deployer:", deployer.address);
  const MigrationLocker = await ethers.getContractFactory("MigrationLocker");

  console.log("Deploying MigrationLocker with transparent proxy...");
  const locker = await upgrades.deployProxy(
    MigrationLocker,
    [TOKEN_ADDRESS, deployer.address],
    { kind: "transparent", initializer: "initialize" }
  );
  await locker.waitForDeployment();
  console.log("MigrationLocker proxy deployed to:", locker.target);

}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
