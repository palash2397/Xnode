// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

//    /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$
//   | $$  / $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/
//   |  $$/ $$/| $$$$| $$| $$  \ $$| $$  \ $$| $$
//    \  $$$$/ | $$ $$ $$| $$  | $$| $$  | $$| $$$$$
//     >$$  $$ | $$  $$$$| $$  | $$| $$  | $$| $$__/
//    /$$/\  $$| $$\  $$$| $$  | $$| $$  | $$| $$
//   | $$  \ $$| $$ \  $$|  $$$$$$/| $$$$$$$/| $$$$$$$$
//   |__/  |__/|__/  \__/ \______/ |_______/ |________/


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ReferralSystem is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public rewardToken;
    address public stakingContract;

    mapping(address => address) private referrers;
    mapping(address => address[]) private referralTree;
    mapping(address => uint256) public pendingRewards;
    mapping(address => bool) public registered;

    uint256[] public rewardPercentages; // e.g., [1000, 250] = 10%, 2.5%
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    // Events
    event ReferralRegistered(address indexed user, address indexed referrer);
    event RewardDistributed(address indexed from, address indexed to, uint256 amount, uint8 level);
    event RewardClaimed(address indexed user, uint256 amount);
    event ReferralConfigUpdated(address token, address staking, uint256[] percentages);

    constructor(address _token, uint256[] memory _percentages) {
        require(_token != address(0), "Invalid token");
        rewardToken = IERC20(_token);
        rewardPercentages = _percentages;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Module 1: Registration & Tree
    function registerReferrer(address user, address referrer) external onlyRole(ADMIN_ROLE) {
        require(user != address(0) && referrer != address(0), "Zero address");
        require(user != referrer, "Self-referral not allowed");
        require(!registered[user], "Already registered");

        // Prevent circular referral
        address current = referrer;
        while (current != address(0)) {
            require(current != user, "Circular referral detected");
            current = referrers[current];
        }

        referrers[user] = referrer;
        referralTree[referrer].push(user);
        registered[user] = true;

        emit ReferralRegistered(user, referrer);
    }

    function getReferrer(address user) external view returns (address) {
        return referrers[user];
    }

    function isRegistered(address user) external view returns (bool) {
        return registered[user];
    }

    function getReferralTree(address user) external view returns (address[] memory) {
        return referralTree[user];
    }

    // Module 2: Reward Distribution
    function distributeReferralReward(address user, uint256 amount) external {
        require(msg.sender == stakingContract, "Unauthorized");

        address currentReferrer = referrers[user];
        for (uint8 level = 0; level < rewardPercentages.length && currentReferrer != address(0); level++) {
            uint256 reward = (amount * rewardPercentages[level]) / PERCENTAGE_DIVISOR;
            pendingRewards[currentReferrer] += reward;
            emit RewardDistributed(user, currentReferrer, reward, level);
            currentReferrer = referrers[currentReferrer];
        }
    }

    function getRewardPercentage(uint8 level) external view returns (uint256) {
        require(level < rewardPercentages.length, "Invalid level");
        return rewardPercentages[level];
    }

    // Module 3: Claiming
    function claimRewards() external nonReentrant whenNotPaused {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "No rewards to claim");

        pendingRewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, amount);
        emit RewardClaimed(msg.sender, amount);
    }

    function getPendingRewards(address user) external view returns (uint256) {
        return pendingRewards[user];
    }

    function updateUserBalance(address user, uint256 amount) external onlyRole(ADMIN_ROLE) {
        pendingRewards[user] = amount;
    }

    // Module 4: Admin Controls
    function setRewardPercentages(uint256[] calldata percentages) external onlyRole(ADMIN_ROLE) {
        rewardPercentages = percentages;
        emit ReferralConfigUpdated(address(rewardToken), stakingContract, percentages);
    }

    function setTokenAddress(address token) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "Invalid address");
        rewardToken = IERC20(token);
    }

    function setStakingContract(address contractAddr) external onlyRole(ADMIN_ROLE) {
        require(contractAddr != address(0), "Invalid address");
        stakingContract = contractAddr;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
