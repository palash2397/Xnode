// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NodeRewardSystem is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public usdt;
    IERC20 public vnode;

    struct Tier {
        uint256 minInvestment;
        uint256 yieldPercent; // Example: 5 for 5%
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

    constructor(address _usdt, address _vnode) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        usdt = IERC20(_usdt);
        vnode = IERC20(_vnode);

        // Example tiers
        tiers.push(Tier(100 * 1e18, 5));
        tiers.push(Tier(1000 * 1e18, 7));
        tiers.push(Tier(5000 * 1e18, 10));
    }

    function invest(uint256 usdtAmount, uint256 vnodeAmount) external {
        require(usdtAmount * 100 / 70 == vnodeAmount * 100 / 30, "Invalid token ratio");

        usdt.transferFrom(msg.sender, address(this), usdtAmount);
        vnode.transferFrom(msg.sender, address(this), vnodeAmount);

        uint8 tier = getTier(usdtAmount + vnodeAmount);
        require(tier < tiers.length, "No matching tier");

        investments[msg.sender] = Investment(usdtAmount, vnodeAmount, tier, true);
    }

    function getTier(uint256 total) public view returns (uint8) {
        for (uint8 i = uint8(tiers.length - 1); i >= 0; i--) {
            if (total >= tiers[i].minInvestment) {
                return i;
            }
        }
        revert("No tier found");
    }

    function submitWorkload(address user, uint256 month, uint256 _hourss, uint256 uptime) external onlyRole(ADMIN_ROLE) {
        require(!workloads[user][month].submitted, "Already submitted");
        workloads[user][month] = Workload(_hourss, uptime, true);
    }

    function calculateReward(address user, uint256 month) external onlyRole(ADMIN_ROLE) {
        Investment memory inv = investments[user];
        require(inv.hasLicense, "No active license");

        Workload memory wl = workloads[user][month];
        require(wl.submitted, "No workload submitted");

        uint256 base = inv.usdtAmount + inv.vnodeAmount;
        uint256 rewardTotal = base * tiers[inv.tier].yieldPercent / 100;

        rewards[user][month] = Reward(
            rewardTotal * 70 / 100,
            rewardTotal * 30 / 100,
            false
        );
    }

    function claim(uint256 month) external {
        Reward storage r = rewards[msg.sender][month];
        require(!r.claimed, "Already claimed");
        require(r.usdtReward > 0 || r.vnodeReward > 0, "No reward");

        r.claimed = true;
        usdt.transfer(msg.sender, r.usdtReward);
        vnode.transfer(msg.sender, r.vnodeReward);
    }
}
