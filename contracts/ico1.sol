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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XnodeTokenICO is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public usdt;

    constructor(address usdt_) ERC20("Xnode", "XODE") Ownable(msg.sender) {
        usdt = IERC20(usdt_);
        uint256 totalSupply = 100000000 * 10**decimals();
        _mint(msg.sender, totalSupply);
    }

    uint256 private saleId;

    bool public saleM = true;

    struct SaleDetail {
        uint256 start;
        uint256 end;
        uint256 price; // in wei per token
        uint256 totalTokens;
        uint256 tokenSold;
        uint256 minBound;
        uint256 raisedIn;
        uint256 remainingToken;
    }

    struct UserToken {
        uint256 saleRound;
        uint256 tokenspurchased;
        uint256 createdOn;
        uint256 remainingTokens;
    }

    struct UserStaking {
        uint256 stakeAmount;
        uint256 claimed;
        uint256 lastClaimedTime;
        uint256 lockingPeriod;
        uint256 totalReward;
        uint256 rewardPerWeek;
    }

    mapping(uint256 => SaleDetail) public salesDetailMap;
    mapping(uint256 => mapping(address => UserToken)) public userTokenMap;
    mapping(uint256 => bool) internal saleIdMap;
    mapping(address => UserStaking) public userStakingMap;

    event BoughtTokens(address indexed to, uint256 value, uint256 saleId);
    event SaleCreated(uint256 saleId);
    event Staked(address indexed from, uint256 value, uint256 duration);
    event claimed(address indexed from, uint256 value);

    uint256 private privateSaleId;
    uint256 private publicSaleId;
    uint256 public minimumStakingAmount;

    function updateSaleIdbyType(uint256 _saleType, uint256 _saleId) internal {
        if (_saleType == 0) {
            privateSaleId = _saleId;
        } else if (_saleType == 1) {
            publicSaleId = _saleId;
        } else {
            revert("Invalid sale type");
        }
    }

    function getSaleIdbyType(uint256 _saleType)
        internal
        view
        returns (uint256)
    {
        uint256 _saleId = _saleType == 0 ? privateSaleId : publicSaleId;
        return _saleId;
    }

    function toggleSale() external onlyOwner {
        saleM = !saleM;
    }

    function startTokenSale(
        uint256 _saleType,
        uint256 _start,
        uint256 _end,
        uint256 _price,
        uint256 _minBound,
        uint256 _totalTokens
    ) external onlyOwner returns (uint256) {
        require(_saleType == 0 || _saleType == 1, "Invalid sale type");
        saleId++;
        updateSaleIdbyType(_saleType, saleId);

        SaleDetail memory detail;

        detail.start = _start;
        detail.end = _end;
        detail.price = _price;
        detail.minBound = _minBound;
        detail.totalTokens = _totalTokens;
        detail.remainingToken = _totalTokens;
        salesDetailMap[saleId] = detail;
        emit SaleCreated(saleId);
        return saleId;
    }

    function isActive(uint256 _saleId) public view returns (bool) {
        SaleDetail memory sale = salesDetailMap[_saleId];
        return (block.timestamp >= sale.start && // Sale has started
            block.timestamp <= sale.end && // Sale has not ended
            !saleIdMap[_saleId]); // Sale is not finalized or goal not reached
    }

    function pause() public onlyOwner {
        pause();
    }

    function unpause() public onlyOwner {
        unpause();
    }

    function calculateToken(uint256 amount, uint256 _rate)
        public
        pure
        returns (uint256)
    {
        return (amount / _rate) * 10**18;
    }

    function buyTokens(uint8 _saleType, uint256 _usdtAmount)
        public
        payable
        nonReentrant
    {
        uint256 _saleId = getSaleIdbyType(_saleType);
        require(isActive(_saleId), "Sale is not active");

        // Ensure user only pays with either ETH or USDT
        require(
            (msg.value > 0 && _usdtAmount == 0) ||
                (msg.value == 0 && _usdtAmount > 0),
            "Pay with either ETH or USDT, not both"
        );

        require(saleM, "the sale is temporary stop");

        SaleDetail storage detail = salesDetailMap[_saleId];
        uint256 tokens;

        if (msg.value > 0) {
            tokens = calculateToken(msg.value, detail.price);
            require(tokens >= detail.minBound, "Not enough tokens");
            require(
                balanceOf(address(this)) >= tokens,
                "Insufficient tokens in contract"
            );

            _transfer(address(this), msg.sender, tokens);
            detail.raisedIn += msg.value;
            payable(owner()).transfer(msg.value);
        } else {
            tokens = calculateToken(_usdtAmount, detail.price);
            require(tokens >= detail.minBound, "Not enough tokens");
            require(
                balanceOf(address(this)) >= tokens,
                "Insufficient tokens in contract"
            );

            usdt.transferFrom(msg.sender, address(this), _usdtAmount);
            _transfer(address(this), msg.sender, tokens);
            detail.raisedIn += _usdtAmount;
        }

        detail.tokenSold += tokens;
        detail.remainingToken -= tokens;

        UserToken storage utoken = userTokenMap[_saleId][msg.sender];
        utoken.saleRound = _saleId;
        utoken.createdOn = block.timestamp;
        utoken.tokenspurchased += tokens;

        emit BoughtTokens(msg.sender, tokens, _saleId);
    }

    function getUSDTbalance() public view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getBNBbalance() public view returns (uint256) {
        return address(this).balance;
    }

    function Withdraw() external onlyOwner {
        uint256 amount = usdt.balanceOf(address(this));
        require(amount > 0, "No usdt to withdraw");
        require(usdt.transfer(owner(), amount), "withdraw failed");
    }

    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No BNB available in contract");
        payable(owner()).transfer(balance);
    }

    function stakeTokens(uint256 _amount, uint256 _durationInDays) external {
        require(_amount > minimumStakingAmount, "Not enough tokens to stake");
        _transfer(msg.sender, address(this), _amount);

        // Calculate the reward per day instead of per week
        uint256 rewardPerDay = (_amount * 10**decimals()) /
            (_durationInDays * 1 days); // 1 day in seconds

        UserStaking storage ustaking = userStakingMap[msg.sender];
        ustaking.stakeAmount += _amount;
        ustaking.lockingPeriod = _durationInDays * 1 days; // Convert days to seconds
        ustaking.rewardPerWeek = rewardPerDay * 7; // Weekly reward
        ustaking.totalReward = ustaking.rewardPerWeek * (_durationInDays / 7); // Total reward based on staking period

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    function calculateRewards(
        address _user,
        uint256 _tokens,
        uint256 _duration
    ) internal returns (uint256) {
        UserStaking storage ustaking = userStakingMap[_user];
        uint256 rewardPercentage;

        // Determine the reward percentage based on duration
        if (_duration == 90 days) {
            rewardPercentage = 10; // 10% weekly for 90 days
        } else if (_duration == 120 days) {
            rewardPercentage = 15; // 15% weekly for 120 days
        } else if (_duration == 180 days) {
            rewardPercentage = 20; // 20% weekly for 180 days
        } else {
            revert("Invalid duration"); // Invalid duration
        }

        // Calculate weekly reward for the given duration
        uint256 weeklyReward = (_tokens * rewardPercentage) / 100; // Reward per week

        // Calculate total rewards for the entire staking period
        uint256 totalRewards = weeklyReward * (_duration / 7 days); // Duration in weeks

        ustaking.totalReward = totalRewards;
        ustaking.rewardPerWeek = weeklyReward;

        // rewardPerWeek
        return weeklyReward;
    }



    function claim() external {
        UserStaking storage ustaking = userStakingMap[msg.sender];
        uint256 rewardAmount = calculateRewards(
            msg.sender,
            ustaking.stakeAmount,
            ustaking.lockingPeriod
        );
        uint256 currentTime = block.timestamp;

        require(
            currentTime > ustaking.lastClaimedTime + 7 days,
            "You can only claim rewards once a week."
        );

        require(
            rewardAmount > ustaking.claimed,
            "No rewards available to claim."
        );

        uint256 claimableReward = rewardAmount - ustaking.claimed;

        _transfer(owner(), msg.sender, claimableReward);
        ustaking.claimed += claimableReward;
        ustaking.lastClaimedTime = currentTime;

        emit claimed(msg.sender, claimableReward);
    }


}
