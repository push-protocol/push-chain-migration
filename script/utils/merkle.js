const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");

// Encode and hash (address, amount, id) using solidityPacked
function hashLeaf(address, amount, id) {
  return ethers.solidityPackedKeccak256([
    "address",
    "uint256",
    "uint256"
  ], [address, amount, id]);
}

// Construct Merkle Tree from array of { address, amount, id }
function getRoot(claims) {
  const leaves = claims.map(({ address, amount, id }) =>
    hashLeaf(address, amount, id)
  );
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  return tree.getHexRoot();
}

// Generate Merkle Proof for a specific address, amount, and id
function getProof(address, amount, id, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount, id }) => hashLeaf(address, amount, id)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount, id);
  return tree.getHexProof(leaf);
}

// Verify Merkle Proof
function verify(address, amount, id, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount, id }) => hashLeaf(address, amount, id)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount, id);
  const proof = tree.getHexProof(leaf);
  return tree.verify(proof, leaf, tree.getHexRoot());
}

module.exports = { getRoot, getProof, verify };
