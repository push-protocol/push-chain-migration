const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const TOKEN_ADDRESS = "0x37c779a1564DCc0e3914aB130e0e787d93e21804"; // PUSH Token
  const amountToMint = ethers.parseUnits("1000", 18); // amount each user gets
  const amountToLock = ethers.parseUnits("100", 18);  // amount each user locks
  const usersCount = 10;

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Load PUSH Token contract with mint function
  const ERC20 = await ethers.getContractFactory("EPNS");
  const pushToken = ERC20.attach(TOKEN_ADDRESS);

  // Deploy MigrationLocker
  const MigrationLocker = await ethers.getContractFactory("MigrationLocker");
  console.log("Deploying MigrationLocker with transparent proxy...");
  const locker = await upgrades.deployProxy(
    MigrationLocker,
    [TOKEN_ADDRESS, deployer.address],
    { kind: "transparent", initializer: "initialize" }
  );
  await locker.waitForDeployment();
  console.log("MigrationLocker deployed at:", await locker.getAddress());

  // Generate 10 wallets and fund them with ETH
  const users = [];
  for (let i = 0; i < usersCount; i++) {
    const wallet = ethers.Wallet.createRandom().connect(ethers.provider);
    users.push(wallet);

    // Send Sepolia ETH
    const tx = await deployer.sendTransaction({
      to: wallet.address,
      value: ethers.parseEther("0.01"),
    });
    await tx.wait();
  }

  // Each user mints PUSH, approves, and locks tokens
  for (const user of users) {
    const userPush = pushToken.connect(user);
    const userLocker = locker.connect(user);

    // Mint tokens by calling mint from the user wallet
    const mintTx = await userPush.mint(amountToMint);
    await mintTx.wait();

    const approveTx = await userPush.approve(await locker.getAddress(), amountToLock);
    await approveTx.wait();

    const lockTx = await userLocker.lock(amountToLock, user.address);
    await lockTx.wait();

    console.log(`🔐 ${user.address} locked ${ethers.formatEther(amountToLock)} PUSH`);
  }

  console.log("✅ All users minted and locked tokens. You can now run the fetch script.");
}

main().catch((err) => {
  console.error("Error in deploy script:", err);
  process.exit(1);
});
