// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const usdtAddr = `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd`;

module.exports = buildModule("LockModule", (m) => {
  const lock = m.contract("XnodeTokenICO", [usdtAddr]);
  return { lock };
});

// npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia
// npx hardhat ignition verify chain-11155111
