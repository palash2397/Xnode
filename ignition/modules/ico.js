// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const usdtAddr = `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd`;

module.exports = buildModule("LockModule", (m) => {
  const lock = m.contract("VnodeTokenICO", [usdtAddr]);
  return { lock };
});


// npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia
// npx hardhat ignition verify chain-11155111

// npx hardhat ignition deploy ./ignition/modules/Lock.js --network bsc-testnet 
// https://testnet.bscscan.com/address/0x7F596417Ff3eE21B0D4B2F3D2f502352a35fe29E#code
// https://testnet.bscscan.com/address/0xC1aDF8E7eB02A1bB4abf5747B8b9118c68ce72de#code