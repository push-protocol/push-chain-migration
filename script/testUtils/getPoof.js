const whitelist = require("../../output/migration-list.json");
const { getProof } = require("../utils/merkle");

const user = whitelist[0];
const proof = getProof(user.address, user.amount, user.epoch, whitelist);
console.log("Merkle Proof for user:", user.address);
console.log(proof);
