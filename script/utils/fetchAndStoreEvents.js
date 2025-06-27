const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");
const { LOCKER_CONFIG, OUTPUT_CONFIG } = require("./config");

async function main() {
  const CONTRACT_ADDRESS = LOCKER_CONFIG.CONTRACT_ADDRESS;
  const LOCKER_ABI = LOCKER_CONFIG.ABI;
  const FILTER_EPOCHS = LOCKER_CONFIG.FILTER_EPOCHS;
  const PUSH_TOKEN_ADDRESS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE";

  const provider = ethers.provider;
  const locker = new ethers.Contract(CONTRACT_ADDRESS, LOCKER_ABI, provider);

  // Add PUSH token interface for balance validation
  const pushToken = new ethers.Contract(PUSH_TOKEN_ADDRESS, [
    "function balanceOf(address account) view returns (uint256)"
  ], provider);

  // Get current epoch from contract
  const currentEpoch = await locker.epoch();
  console.log(`🔢 Current epoch: ${currentEpoch}`);

  // Determine which epochs to process
  let epochsToProcess = [];
  if (FILTER_EPOCHS && FILTER_EPOCHS.length > 0) {
    epochsToProcess = FILTER_EPOCHS.filter(e => e <= currentEpoch);
    console.log(`🔍 Processing specific epochs: ${epochsToProcess.join(', ')}`);
  } else {
    // Process all epochs from 1 to current
    for (let i = 1; i <= currentEpoch; i++) {
      epochsToProcess.push(i);
    }
    console.log(`🔍 Processing all epochs from 1 to ${currentEpoch}`);
  }

  // Get the overall start and end blocks for the entire range
  const firstEpoch = Math.min(...epochsToProcess);
  const lastEpoch = Math.max(...epochsToProcess);

  const startBlock = await locker.epochStartBlock(firstEpoch);
  let endBlock = "latest";
  if (lastEpoch < currentEpoch) {
    const nextEpochStart = await locker.epochStartBlock(lastEpoch + 1);
    endBlock = Number(nextEpochStart) - 1;
  }

  console.log(`📊 Fetching all Locked events from blocks ${startBlock} to ${endBlock}...`);

  // Single query for all events in the range
  const allEvents = await locker.queryFilter("Locked", startBlock, endBlock);
  console.log(`📦 Found ${allEvents.length} total Locked events`);

  // Group events by address and combine amounts
  const addressAmounts = {};
  let totalEvents = 0;
  const epochTotals = {}; // Track total amount per epoch from events

  // Process events and filter by epoch on the client side
  for (const event of allEvents) {
    const eventEpoch = Number(event.args.epoch);

    // Skip events from epochs we're not interested in
    if (!epochsToProcess.includes(eventEpoch)) {
      continue;
    }

    const address = event.args.recipient;
    const amount = BigInt(event.args.amount.toString());

    const key = `${address}-${eventEpoch}`;

    if (addressAmounts[key]) {
      // Address already exists in this epoch, add to existing amount
      addressAmounts[key].amount = addressAmounts[key].amount + amount;
      console.log(`📝 Combined amount for ${address} in epoch ${eventEpoch}`);
    } else {
      // First occurrence of this address in this epoch
      addressAmounts[key] = {
        address: address,
        amount: amount,
        epoch: eventEpoch.toString()
      };
    }

    // Track total per epoch
    if (!epochTotals[eventEpoch]) {
      epochTotals[eventEpoch] = BigInt(0);
    }
    epochTotals[eventEpoch] += amount;

    totalEvents++;
  }

  // Convert to array format with combined amounts
  const claims = Object.values(addressAmounts).map(claim => ({
    address: claim.address,
    amount: claim.amount.toString(),
    epoch: claim.epoch
  }));

  console.log(`📊 Processed ${totalEvents} events into ${claims.length} unique address-epoch combinations`);

  // Show some statistics
  const duplicateCount = totalEvents - claims.length;
  if (duplicateCount > 0) {
    console.log(`🔄 Combined ${duplicateCount} duplicate addresses`);
  }

  // Validate that sum of all leaves equals on-chain locked amounts
  console.log(`\n🔍 Validating totals against on-chain state...`);

  for (const epoch of epochsToProcess) {
    const offChainTotal = epochTotals[epoch] || BigInt(0);

    // Get on-chain total (incremental balance for this epoch)
    let onChainTotal;
    if (epoch === currentEpoch) {
      // For current epoch: current balance minus balance at start of current epoch
      const currentBalance = await pushToken.balanceOf(CONTRACT_ADDRESS);
      const currentEpochStart = await locker.epochStartBlock(currentEpoch);
      const balanceAtStart = await pushToken.balanceOf(CONTRACT_ADDRESS, {
        blockTag: Number(currentEpochStart) - 1
      });
      onChainTotal = currentBalance - balanceAtStart;
    } else {
      // For past epochs: balance at end of epoch minus balance at start of epoch
      const nextEpochStart = await locker.epochStartBlock(epoch + 1);
      const epochStart = await locker.epochStartBlock(epoch);

      const endBlockOfEpoch = Number(nextEpochStart) - 1;
      const startBlockOfEpoch = Number(epochStart) - 1;

      const endBalance = await pushToken.balanceOf(CONTRACT_ADDRESS, { blockTag: endBlockOfEpoch });
      const startBalance = await pushToken.balanceOf(CONTRACT_ADDRESS, { blockTag: startBlockOfEpoch });
      onChainTotal = endBalance - startBalance;
    }

    if (offChainTotal !== onChainTotal) {
      console.error(`❌ Validation failed for epoch ${epoch}:`);
      console.error(`   Off-chain total: ${offChainTotal.toString()}`);
      console.error(`   On-chain total: ${onChainTotal.toString()}`);
      console.error(`   Difference: ${(offChainTotal > onChainTotal ? offChainTotal - onChainTotal : onChainTotal - offChainTotal).toString()}`);
      throw new Error(`Funds may be missing for epoch ${epoch}`);
    }

    console.log(`✅ Epoch ${epoch}: ${offChainTotal.toString()} wei`);
  }

  console.log(`\n✅ All validations passed!`);

  const outputPath = path.join(__dirname, OUTPUT_CONFIG.CLAIMS_PATH);
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