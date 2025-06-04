const whitelist = require("../../output/claims.json");
const { verify } = require("../utils/merkle");

const user = whitelist[0];
const isValid = verify(user.address, user.amount, whitelist);
console.log("Proof valid?", isValid);
