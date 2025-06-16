const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const usdt = `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd`;
const vnode = `0x2B73aa8A002482D537D345814D4524acbC0EB489`


module.exports = buildModule("LockModule", (m) => {
  const lock = m.contract("NodeRewardSystem", [usdt, vnode]);
  return { lock };
});


// https://testnet.bscscan.com/address/0x97284b5c91dd66dAe01b16eB84c58a1b715F79Fb#code