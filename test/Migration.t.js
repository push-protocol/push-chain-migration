const { expect } = require("chai");
const { ethers } = require("hardhat");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");

describe("Migration Merkle Test", function () {
    let locker, release, pushToken, owner, user1, user2, user3, additionalUsers;
    let tree, claims;

    beforeEach(async () => {
        [owner, user1, user2, user3, ...additionalUsers] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("EPNS");
        pushToken = await Token.deploy(owner.address);

        await pushToken.transfer(user1.address, ethers.parseEther("1000"));
        await pushToken.transfer(user2.address, ethers.parseEther("2000"));
        await pushToken.transfer(user3.address, ethers.parseEther("3000"));

        for (const user of additionalUsers.slice(0, 5)) {
            await pushToken.transfer(user.address, ethers.parseEther("500"));
        }

        const MigrationLocker = await ethers.getContractFactory("MigrationLocker");
        locker = await upgrades.deployProxy(
            MigrationLocker,
            [pushToken.target, owner.address],
            { kind: "transparent", initializer: "initialize" }
        );
        await locker.waitForDeployment();

        await pushToken.connect(user1).approve(locker.target, ethers.parseEther("100"));
        await locker.connect(user1).lock(ethers.parseEther("100"), user1.address);

        await pushToken.connect(user2).approve(locker.target, ethers.parseEther("200"));
        await locker.connect(user2).lock(ethers.parseEther("200"), user2.address);

        await pushToken.connect(user3).approve(locker.target, ethers.parseEther("200"));
        await locker.connect(user3).lock(ethers.parseEther("200"), user3.address);

        for (const [i, user] of additionalUsers.slice(0, 5).entries()) {
            const amount = ethers.parseEther((50 * (i + 1)).toString());
            await pushToken.connect(user).approve(locker.target, amount);
            await locker.connect(user).lock(amount, user.address);
        }

        const events = await locker.queryFilter(locker.filters.Locked());
        claims = events.map(e => ({
            address: e.args.recipient,
            amount: e.args.amount,
            id: e.args.id,
        }));

        const leaves = claims.map(({ address, amount, id }) =>
            ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [address, amount, id])
        );

        tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        const root = tree.getHexRoot();

        const Release = await ethers.getContractFactory("MigrationRelease");
        release = await upgrades.deployProxy(Release, [owner.address], { kind: "transparent", initializer: "initialize" })
        await release.connect(owner).addFunds({ value: ethers.parseEther("10000") });
        await release.connect(owner).transferOwnership(owner.address);
        await release.connect(owner).setMerkleRoot(root);
    });

    it("✅ allows all users to claim with valid proof and receive correct instant amount", async () => {
        for (const userClaim of claims) {
            const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, userClaim.amount, userClaim.id]);
            const proof = tree.getHexProof(leaf);

            const beforeBalance = await ethers.provider.getBalance(userClaim.address);
            await expect(
                release.connect(owner).releaseInstant(userClaim.address, userClaim.amount, userClaim.id, proof)
            ).to.emit(release, "ReleasedInstant");

            const afterBalance = await ethers.provider.getBalance(userClaim.address);
            const expected = userClaim.amount * 5n;
            const actual = afterBalance - beforeBalance;

            expect(actual).to.equal(expected);
        }
    });

    it("❌ fails if proof is invalid", async () => {
        const badLeaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [user1.address, ethers.parseEther("999"), 9]);
        const badProof = tree.getHexProof(badLeaf);

        await expect(
            release.releaseInstant(user1.address, ethers.parseEther("999"), 9, badProof)
        ).to.be.revertedWith("Not Whitelisted or already Claimed");
    });

    it("❌ prevents double claim", async () => {
        const userClaim = claims[0];
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, userClaim.amount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        await release.releaseInstant(userClaim.address, userClaim.amount, userClaim.id, proof);

        await expect(
            release.releaseInstant(userClaim.address, userClaim.amount, userClaim.id, proof)
        ).to.be.revertedWith("Not Whitelisted or already Claimed");
    });

    it("❌ rejects claims with correct address but wrong amount", async () => {
        const userClaim = claims[1];
        const wrongAmount = ethers.parseEther("1");
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, wrongAmount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        await expect(
            release.releaseInstant(userClaim.address, wrongAmount, userClaim.id, proof)
        ).to.be.revertedWith("Not Whitelisted or already Claimed");
    });

    it("❌ rejects claims with correct amount but wrong address", async () => {
        const userClaim = claims[2];
        const wrongAddress = additionalUsers[0].address;
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [wrongAddress, userClaim.amount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        await expect(
            release.releaseInstant(wrongAddress, userClaim.amount, userClaim.id, proof)
        ).to.be.revertedWith("Not Whitelisted or already Claimed");
    });

    it("✅ allows vested claim after instant and validates correct vested amount", async () => {
        const userClaim = claims[3];
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, userClaim.amount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        const before = await ethers.provider.getBalance(userClaim.address);
        await release.connect(owner).releaseInstant(userClaim.address, userClaim.amount, userClaim.id, proof);
        await ethers.provider.send("evm_increaseTime", [90 * 24 * 60 * 60]);
        await ethers.provider.send("evm_mine");

        await release.connect(owner).releaseVested(userClaim.address, userClaim.amount, userClaim.id);
        const after = await ethers.provider.getBalance(userClaim.address);

        const expected = userClaim.amount * 12n; // 5x + 10x
        const actual = after - before;
        expect(actual).to.equal(expected);
    });

    it("❌ fails if vested is called before instant", async () => {
        const userClaim = claims[4];
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, userClaim.amount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        await expect(
            release.connect(owner).releaseVested(userClaim.address, userClaim.amount, userClaim.id)
        ).to.be.revertedWith("Not Whitelisted or Not Vested");
    });

    // Simple test for the totalReleased counter
    it("✅ tracks totalReleased correctly", async () => {
        const userClaim = claims[0];
        const leaf = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [userClaim.address, userClaim.amount, userClaim.id]);
        const proof = tree.getHexProof(leaf);

        const beforeTotal = await release.totalReleased();

        // Do instant release
        await release.connect(owner).releaseInstant(userClaim.address, userClaim.amount, userClaim.id, proof);

        const afterInstantTotal = await release.totalReleased();
        expect(afterInstantTotal - beforeTotal).to.equal(userClaim.amount * 5n);

        // Wait for vesting period
        await ethers.provider.send("evm_increaseTime", [90 * 24 * 60 * 60]);
        await ethers.provider.send("evm_mine");

        // Do vested release
        await release.connect(owner).releaseVested(userClaim.address, userClaim.amount, userClaim.id);

        const afterVestedTotal = await release.totalReleased();
        expect(afterVestedTotal - afterInstantTotal).to.equal(userClaim.amount * 7n);
    });

    // Simple test for invalid merkle root
    it("❌ prevents setting invalid merkle root", async () => {
        await expect(
            release.connect(owner).setMerkleRoot(ethers.ZeroHash)
        ).to.be.revertedWith("Invalid Merkle Root");

        const currentRoot = await release.merkleRoot();
        await expect(
            release.connect(owner).setMerkleRoot(currentRoot)
        ).to.be.revertedWith("Invalid Merkle Root");
    });

    it("Admin can burn tokens", async () => {
        const amountToBurn = ethers.parseEther("100");
        const initialBalance = await pushToken.balanceOf(locker.target);

        await locker.connect(owner).burn(amountToBurn);

        const finalBalance = await pushToken.balanceOf(locker.target);
        expect(finalBalance).to.equal(initialBalance - amountToBurn);
    }
    );
});