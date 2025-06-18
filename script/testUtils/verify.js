const whitelist = require("../../output/migration-list.json");
const { verify } = require("../utils/merkle");

const user = whitelist[0];
const isValid = verify(user.address, user.amount, user.epoch, whitelist);
console.log("Proof valid?", isValid);
