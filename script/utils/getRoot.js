const whitelist = require("../../output/claims.json");
const { getRoot } = require("./merkle");

console.log("Merkle Root:", getRoot(whitelist));
