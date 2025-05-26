const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0x5f4A632526a907003879dAd557dBdcf624EBe992"; // replace with actual address
  const LOCKER_ABI = [
    "event Locked(address recipient, uint256 amount)" // Removed indexed id
  ];

  const provider = ethers.provider;
  const locker = new ethers.Contract(CONTRACT_ADDRESS, LOCKER_ABI, provider);

  console.log("🔍 Fetching Locked events...");
  const events = await locker.queryFilter("Locked", 0, "latest");
  console.log(`📦 Found ${events.length} Locked events.`);

  // Group events by address and combine amounts
  const addressAmounts = {};
  
  events.forEach(event => {
    const address = event.args.recipient;
    const amount = BigInt(event.args.amount.toString());
    
    if (addressAmounts[address]) {
      // Address already exists, add to existing amount
      addressAmounts[address] = addressAmounts[address] + amount;
      console.log(`📝 Combined amount for ${address}`);
    } else {
      // First occurrence of this address
      addressAmounts[address] = amount;
    }
  });

  // Convert to array format with combined amounts
  const claims = Object.entries(addressAmounts).map(([address, totalAmount]) => ({
    address: address,
    amount: totalAmount.toString()
  }));

  console.log(`📊 Processed ${events.length} events into ${claims.length} unique addresses`);
  
  // Show some statistics
  const duplicateCount = events.length - claims.length;
  if (duplicateCount > 0) {
    console.log(`🔄 Combined ${duplicateCount} duplicate addresses`);
  }

  const outputPath = path.join(__dirname, "../../output/claims.json");
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(claims, null, 2));

  console.log(`✅ Saved ${claims.length} unique claims to ${outputPath}`);
  
  // Optional: Show top 5 addresses by amount for verification
  const sortedClaims = claims.sort((a, b) => {
    const amountA = BigInt(a.amount);
    const amountB = BigInt(b.amount);
    return amountB > amountA ? 1 : amountB < amountA ? -1 : 0;
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});