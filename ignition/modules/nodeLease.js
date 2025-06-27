const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const usdt = `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd`;


module.exports = buildModule("LockModule", (m) => {
  const lock = m.contract("NodeLeasing", [usdt]);
  return { lock };
});







// ✅ EOD

// Work on the following tasks today:

// Implemented the Node Logic module to handle node registration, leasing, rent payments, and withdrawals

// Developed the Admin Control module to manage pausing, blacklisting, and restricting sensitive functions to admins

// Integrated both modules into the main NodeLeasing contract

// Performed end-to-end testing to ensure all functions work as expected

// ✅ Successfully deployed the smart contract on BSC Testnet

// 🔗 Testnet Contract Link:

//  https://testnet.bscscan.com/address/0xf2C02Ed73d24a9763893dCA8F12053Fbe05C08F7#code