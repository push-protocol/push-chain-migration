const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");

// Encode and hash (address, amount, id) using solidityPacked
function hashLeaf(address, amount) {
  return ethers.solidityPackedKeccak256([
    "address",
    "uint256"
  ], [address, amount]);
}

// Construct Merkle Tree from array of { address, amount, id }
function getRoot(claims) {
  const leaves = claims.map(({ address, amount}) =>
    hashLeaf(address, amount)
  );
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  return tree.getHexRoot();
}

// Generate Merkle Proof for a specific address, amount, and id
function getProof(address, amount, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount }) => hashLeaf(address, amount)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount);
  return tree.getHexProof(leaf);
}

// Verify Merkle Proof
function verify(address, amount, claims) {
  const tree = new MerkleTree(
    claims.map(({ address, amount}) => hashLeaf(address, amount)),
    ethers.keccak256,
    { sortPairs: true }
  );
  const leaf = hashLeaf(address, amount);
  const proof = tree.getHexProof(leaf);
  return tree.verify(proof, leaf, tree.getHexRoot());
}

module.exports = { getRoot, getProof, verify };
