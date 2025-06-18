const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");

// Encode and hash (address, amount, epoch) using solidityPacked
function hashLeaf(address, amount, epoch) {
  return ethers.solidityPackedKeccak256([
    "address",
    "uint256",
    "uint256"
  ], [address, amount, epoch]);
}

// Construct Merkle Tree from array of { address, amount, epoch }
function getRoot(claims) {
  const leaves = claims.map(({ address, amount, epoch }) =>
    hashLeaf(address, amount, epoch)
  );
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  return tree.getHexRoot();
}

// Generate Merkle Proof for a specific address, amount, and epoch
function getProof(address, amount, epoch, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount, epoch }) => hashLeaf(address, amount, epoch)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount, epoch);
  return tree.getHexProof(leaf);
}

// Verify Merkle Proof
function verify(address, amount, epoch, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount, epoch }) => hashLeaf(address, amount, epoch)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount, epoch);
  const proof = tree.getHexProof(leaf);
  return tree.verify(proof, leaf, tree.getHexRoot());
}

module.exports = { getRoot, getProof, verify };
