const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");
const { getProof, getRoot } = require("../utils/merkle");

async function main() {
    const claimsPath = path.join(__dirname, "../../output/migration-list.json");
    const claims = JSON.parse(fs.readFileSync(claimsPath, "utf8"));

    const [deployer] = await ethers.getSigners();
    const RELEASE_ADDRESS = "0xE6f6f9fA92e6d8A974Ec79a69cD8D97f7dEC15E7"; // Replace with actual address

    const Release = await ethers.getContractFactory("MigrationRelease");
    const release = Release.attach(RELEASE_ADDRESS);

    console.log("🔑 Using signer:", deployer.address);

    // Fund release contract with enough ETH (15x multiplier per claim)
    const totalRequired = claims.reduce((acc, c) => acc + BigInt(c.amount) * 15n, 0n);
    const fundTx = await release.connect(deployer).addFunds({ value: totalRequired });
    await fundTx.wait();

    console.log(`✅ Funded with ${ethers.formatEther(totalRequired)} ETH`);

    // Set Merkle root
    // console.log("📌 Merkle root updated:");
    // const root = getRoot(claims);
    // const tx = await release.setMerkleRoot(root);
    // await tx.wait();
    // console.log("📌 Merkle root updated:", root);


    // Uncomment the following lines to test the instant release phase

    // Instant release phase
    // for (const { address, amount } of claims) {
    //     const proof = getProof(address, amount, claims);

    //     const before = await ethers.provider.getBalance(address);
    //     const tx = await release.releaseInstant(address, amount, proof);
    //     await tx.wait();
    //     const after = await ethers.provider.getBalance(address);

    //     const received = after - before;
    //     const expected = (BigInt(amount) * 75n) / 10n;

    //     console.log(`💸 ${address} received instant ${ethers.formatEther(received)} ETH`);

    //     if (received !== expected) {
    //         console.warn(`⚠️ WARNING: expected ${expected}, got ${received}`);
    //     }
    // }

    // Vested release phase
    for (const { address, amount } of claims) {
        const proof = getProof(address, amount, claims);

        const before = await ethers.provider.getBalance(address);
        try {
            const tx = await release.releaseVested(address, amount);
            await tx.wait();
            const after = await ethers.provider.getBalance(address);

            const received = after - before;
            const expected = (BigInt(amount) *  75n) / 10n;

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