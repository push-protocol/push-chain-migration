const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");
const { getProof, getRoot } = require("../utils/merkle");

async function main() {
    const claimsPath = path.join(__dirname, "../../output/claims.json");
    const claims = JSON.parse(fs.readFileSync(claimsPath, "utf8"));

    const [deployer] = await ethers.getSigners();
    const RELEASE_ADDRESS = "0x7121D0Bf677847cA41601838824f39a7d5146310"; // Replace with actual address

    const Release = await ethers.getContractFactory("MigrationRelease");
    const release = Release.attach(RELEASE_ADDRESS);

    console.log("🔑 Using signer:", deployer.address);

    // Fund release contract with enough ETH (15x multiplier per claim)
    const totalRequired = claims.reduce((acc, c) => acc + BigInt(c.amount) * 15n, 0n);
    const fundTx = await release.connect(deployer).addFunds({ value: totalRequired });
    await fundTx.wait();

    console.log(`✅ Funded with ${ethers.formatEther(totalRequired)} ETH`);

    // Set Merkle root
    const root = getRoot(claims);
    const tx = await release.setMerkleRoot(root);
    await tx.wait();
    console.log("📌 Merkle root updated:", root);


    // Uncomment the following lines to test the instant release phase

    // Instant release phase
    // for (const { address, amount, id } of claims) {
    //     const proof = getProof(address, amount, id, claims);

    //     const before = await ethers.provider.getBalance(address);
    //     const tx = await release.releaseInstant(address, amount, id, proof);
    //     await tx.wait();
    //     const after = await ethers.provider.getBalance(address);

    //     const received = after - before;
    //     const expected = BigInt(amount) * 5n;

    //     console.log(`💸 ${address} received instant ${ethers.formatEther(received)} ETH`);

    //     if (received !== expected) {
    //         console.warn(`⚠️ WARNING: expected ${expected}, got ${received}`);
    //     }
    // }

    // Vested release phase
    for (const { address, amount, id } of claims) {
        const proof = getProof(address, amount, id, claims);

        const before = await ethers.provider.getBalance(address);
        try {
            const tx = await release.releaseVested(address, amount, id);
            await tx.wait();
            const after = await ethers.provider.getBalance(address);

            const received = after - before;
            const expected = BigInt(amount) * 10n;

            console.log(`💰 ${address} received vested ${ethers.formatEther(received)} ETH`);

            if (received !== expected) {
                console.warn(`⚠️ Unexpected vested amount. Expected ${ethers.formatEther(expected)} ETH`);
            }
        } catch (err) {
            console.error(`❌ Vested release failed for ${address}:`, err.message);
        }
    }

    console.log("✅ All claims processed.");
}

main().catch(err => {
    console.error("❌ Error during release:", err);
    process.exit(1);
});