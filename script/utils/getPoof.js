const whitelist = require("../../output/claims.json");
const { getProof } = require("./merkle");

const user = whitelist[0];
const proof = getProof(user.address, user.amount, whitelist);
console.log("Merkle Proof for user:", user.address);
console.log(proof);
