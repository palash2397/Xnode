const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const token = `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd`;
const percentages = [1000, 2000]

module.exports = buildModule("LockModule", (m) => {
  const lock = m.contract("ReferralSystem", [token, percentages]);
  return { lock };
});




// npx hardhat ignition deploy ./ignition/modules/referral.js --network bsc-testnet
// npx hardhat ignition verify chain-97