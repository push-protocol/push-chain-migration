const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0xb3Fd1780751d4e1C1Edcabd631afC28aDf3ba509"; // replace with actual address
  const LOCKER_ABI = [
    "event Locked(address recipient, uint256 amount, uint256 indexed id)"
  ];

  const provider = ethers.provider;
  const locker = new ethers.Contract(CONTRACT_ADDRESS, LOCKER_ABI, provider);

  console.log("🔍 Fetching Locked events...");
  const events = await locker.queryFilter("Locked", 0, "latest");
  console.log(`📦 Found ${events.length} Locked events.`);

  const claims = events.map(e => ({
    address: e.args.recipient,
    amount: e.args.amount.toString(),
    id: e.args.id.toString()
  }));

  const outputPath = path.join(__dirname, "../output/claims.json");
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(claims, null, 2));

  console.log(`✅ Saved claims to ${outputPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});