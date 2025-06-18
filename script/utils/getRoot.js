const path = require("path");
const { OUTPUT_CONFIG } = require("./config");
const { getRoot } = require("./merkle");

// Use the path from config
const claimsPath = path.join(__dirname, OUTPUT_CONFIG.CLAIMS_PATH);
const whitelist = require(claimsPath);

console.log("Merkle Root:", getRoot(whitelist));
