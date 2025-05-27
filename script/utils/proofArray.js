const whitelist = require("../../output/claims.json");
const { getProof, verify } = require("./merkle");

for (const user of whitelist) {
  const proof = getProof(user.address, user.amount, whitelist);
  const valid = verify(user.address, user.amount, whitelist);

  console.log("User:", user.address);
  console.log("Proof:", proof);
  console.log("Valid:", valid);
}
