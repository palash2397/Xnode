// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition


const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
 
  const lock = m.contract("Vnode", []);

  return { lock };
});


// npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia
// npx hardhat ignition verify chain-11155111


