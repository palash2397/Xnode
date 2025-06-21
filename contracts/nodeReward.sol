// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//    /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$
//   | $$  / $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/
//   |  $$/ $$/| $$$$| $$| $$  \ $$| $$  \ $$| $$
//    \  $$$$/ | $$ $$ $$| $$  | $$| $$  | $$| $$$$$
//     >$$  $$ | $$  $$$$| $$  | $$| $$  | $$| $$__/
//    /$$/\  $$| $$\  $$$| $$  | $$| $$  | $$| $$
//   | $$  \ $$| $$ \  $$|  $$$$$$/| $$$$$$$/| $$$$$$$$
//   |__/  |__/|__/  \__/ \______/ |_______/ |________/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NodeRewardSystem is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public usdt;
    IERC20 public vnode;

    struct Tier {
        uint256 minInvestment;
        uint256 yieldPercent; // 5 = 5%
    }

    struct Investment {
        uint256 usdtAmount;
        uint256 vnodeAmount;
        uint8 tier;
        bool hasLicense;
    }

    struct Workload {
        uint256 hourss;
        uint256 uptime;
        bool submitted;
    }

    struct Reward {
        uint256 usdtReward;
        uint256 vnodeReward;
        bool claimed;
    }

    mapping(address => Investment) public investments;
    mapping(address => mapping(uint256 => Workload)) public workloads; // user => month => workload
    mapping(address => mapping(uint256 => Reward)) public rewards;     // user => month => reward
    Tier[] public tiers;

    event Invested(address indexed user, uint256 usdtAmount, uint256 vnodeAmount, uint8 tier);
    event WorkloadSubmitted(address indexed user, uint256 month, uint256 hours, uint256 uptime);
    event RewardCalculated(address indexed user, uint256 month, uint256 usdtReward, uint256 vnodeReward);
    event RewardClaimed(address indexed user, uint256 month);
    event AdminWithdrawal(address indexed token, uint256 amount);

    constructor(address _usdt, address _vnode) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        usdt = IERC20(_usdt);
        vnode = IERC20(_vnode);

        // Setup default tiers
        tiers.push(Tier(100 * 1e18, 5));
        tiers.push(Tier(1000 * 1e18, 7));
        tiers.push(Tier(5000 * 1e18, 10));
    }

    function invest(uint256 usdtAmount, uint256 vnodeAmount) external {
        require(usdtAmount > 0 && vnodeAmount > 0, "Amounts must be > 0");

        uint256 total = usdtAmount + vnodeAmount;
        require(total >= tiers[0].minInvestment, "Below minimum tier");

        // Maintain exact 70:30 ratio
        require(
            usdtAmount * 100 / 70 == vnodeAmount * 100 / 30,
            "Invalid token ratio"
        );

        require(!investments[msg.sender].hasLicense, "Already invested");

        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        require(vnode.transferFrom(msg.sender, address(this), vnodeAmount), "VNode transfer failed");

        uint8 tier = getTier(total);
        require(tier < tiers.length, "No matching tier");

        investments[msg.sender] = Investment(usdtAmount, vnodeAmount, tier, true);

        emit Invested(msg.sender, usdtAmount, vnodeAmount, tier);
    }

    function getTier(uint256 total) public view returns (uint8) {
        for (uint8 i = uint8(tiers.length); i > 0; i--) {
            if (total >= tiers[i - 1].minInvestment) {
                return i - 1;
            }
        }
        revert("No tier found");
    }

    function submitWorkload(address user, uint256 month, uint256 hourss, uint256 uptime) external onlyRole(ADMIN_ROLE) {
        require(!workloads[user][month].submitted, "Already submitted");
        workloads[user][month] = Workload(hourss, uptime, true);
        emit WorkloadSubmitted(user, month, hourss, uptime);
    }

    function calculateReward(address user, uint256 month) external onlyRole(ADMIN_ROLE) {
        Investment memory inv = investments[user];
        require(inv.hasLicense, "No license");

        Workload memory wl = workloads[user][month];
        require(wl.submitted, "No workload");

        require(!rewards[user][month].claimed && rewards[user][month].usdtReward == 0, "Reward already exists");

        uint256 base = inv.usdtAmount + inv.vnodeAmount;
        uint256 rewardTotal = (base * tiers[inv.tier].yieldPercent) / 100;

        rewards[user][month] = Reward(
            (rewardTotal * 70) / 100,
            (rewardTotal * 30) / 100,
            false
        );

        emit RewardCalculated(user, month, (rewardTotal * 70) / 100, (rewardTotal * 30) / 100);
    }

    function claim(uint256 month) external {
        Reward storage r = rewards[msg.sender][month];
        require(!r.claimed, "Already claimed");
        require(r.usdtReward > 0 || r.vnodeReward > 0, "Nothing to claim");

        r.claimed = true;

        require(usdt.transfer(msg.sender, r.usdtReward), "USDT claim failed");
        require(vnode.transfer(msg.sender, r.vnodeReward), "VNode claim failed");

        emit RewardClaimed(msg.sender, month);
    }

    function adminWithdraw(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance");
        require(IERC20(token).transfer(msg.sender, balance), "Withdraw failed");

        emit AdminWithdrawal(token, balance);
    }

    function getTierInfo(uint8 tierId) external view returns (Tier memory) {
        return tiers[tierId];
    }

    function getInvestment(address user) external view returns (Investment memory) {
        return investments[user];
    }

    function getReward(address user, uint256 month) external view returns (Reward memory) {
        return rewards[user][month];
    }

    function getWorkload(address user, uint256 month) external view returns (Workload memory) {
        return workloads[user][month];
    }
}
