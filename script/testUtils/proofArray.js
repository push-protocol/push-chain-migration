const whitelist = require("../../output/migration-list.json");
const { getProof, verify } = require("../utils/merkle");

for (const user of whitelist) {
  const proof = getProof(user.address, user.amount, user.epoch, whitelist);
  const valid = verify(user.address, user.amount, user.epoch, whitelist);

  console.log("User:", user.address);
  console.log("Proof:", proof);
  console.log("Valid:", valid);
}
