// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;



//  /$$    /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$
// | $$   | $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/
// | $$   | $$| $$$$| $$| $$  \ $$| $$  \ $$| $$      
// |  $$ / $$/| $$ $$ $$| $$  | $$| $$  | $$| $$$$$   
//  \  $$ $$/ | $$  $$$$| $$  | $$| $$  | $$| $$__/   
//   \  $$$/  | $$\  $$$| $$  | $$| $$  | $$| $$      
//    \  $/   | $$ \  $$|  $$$$$$/| $$$$$$$/| $$$$$$$$
//     \_/    |__/  \__/ \______/ |_______/ |________/
                                                
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XnodeTokenICO is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    uint256 public icoStart;
    uint256 public icoEnd;
    bool public manualPause;
    uint256 public soldTokens;
    uint256 public tokenPrice;
    address private ownerAddress = 0xC9d9A549D0753Cff3B6fF477fabA7614a0b0C6D1;

    // vesting part
    uint256 public lockDuration = 6 * 30 days;
    uint256 public vestingInterval = 3 * 30 days;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 lockEndTime;
        uint256 unlockPerBatch;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    struct SalePhaseInfo {
        uint256 allocatedSupply;
        uint256 price;
        uint256 lockingPeriod;
    }

    enum SalePhase {
        notStarted,
        Privatesale,
        Presale1,
        Presale2,
        Publicsale,
        Pause,
        Ended
    }
    SalePhase public salePhase;
    mapping(SalePhase => SalePhaseInfo) public salePhases;

    struct LockingSchedule {
        uint256 amount;
        uint256 purchaseTime;
        SalePhase phase;
        uint256 unlockTime;
    }

    mapping(address => LockingSchedule[]) public lockingBalances;

    mapping(SalePhase => address[]) public phaseBuyers;

    event TokenBought(
        address indexed buyer,
        uint256 usdtAmount,
        uint256 tokenAmount,
        uint256 unlockTime
    );
    event TokensClaimed(address indexed buyer, uint256 amount);

    struct UserSaleDetails {
        uint256 saleType;
        uint256 totalTokens;
    }

    mapping(address => UserSaleDetails) public userDetails;

    constructor(
        address usdt_
    ) ERC20("Xnode", "XODE") Ownable(msg.sender) {
        usdt = IERC20(usdt_);

        uint256 totalSupply = 40000000 * 10 ** decimals();
        _mint(ownerAddress, totalSupply);

        salePhases[SalePhase.Privatesale] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            5 * 10 ** 16,
            730 days
        );
        salePhases[SalePhase.Presale1] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            7 * 10 ** 16,
            730 days
        );
        salePhases[SalePhase.Presale2] = SalePhaseInfo(
            (totalSupply * 10) / 100,
            9 * 10 ** 16,
            730 days
        );
        salePhases[SalePhase.Publicsale] = SalePhaseInfo(
            (totalSupply * 5) / 100,
            12 * 10 ** 16,
            730 days
        ); // No lock

        salePhase = SalePhase.notStarted;
    }

    modifier onlyDuringICO() {
        require(
            block.timestamp >= icoStart && block.timestamp <= icoEnd,
            "ICO is not active"
        );
        _;
    }

    function setStartTime(uint256 startTime_) external onlyOwner {
        require(
            startTime_ > block.timestamp,
            "Start time must be in the future"
        );
        icoStart = startTime_;
    }

    function setEndTime(uint256 endTime_) external onlyOwner {
        require(endTime_ > icoStart, "End time must be after start time");
        icoEnd = endTime_;
    }

    function PauseResume() external onlyOwner {
        manualPause = !manualPause;
        if (manualPause) {
            salePhase = SalePhase.Pause;
        }
    }

    function setLockingPeriod(
        SalePhase phase,
        uint256 period
    ) external onlyOwner {
        require(salePhases[phase].allocatedSupply > 0, "Invalid sale phase");
        salePhases[phase].lockingPeriod = period;

        address[] storage buyers = phaseBuyers[phase];
        for (uint256 i = 0; i < buyers.length; i++) {
            LockingSchedule[] storage schedules = lockingBalances[buyers[i]];
            for (uint256 j = 0; j < schedules.length; j++) {
                if (schedules[j].amount > 0 && schedules[j].phase == phase) {
                    schedules[j].unlockTime =
                        schedules[j].purchaseTime +
                        period;
                }
            }
        }
    }

    function setSalePhase(SalePhase phase) external onlyOwner {
        require(!manualPause, "Cannot change phase while ICO is paused");
        require(
            (phase == SalePhase.Privatesale &&
                salePhase == SalePhase.notStarted) ||
                (phase == SalePhase.Presale1 &&
                    salePhase == SalePhase.Privatesale) ||
                (phase == SalePhase.Presale2 &&
                    salePhase == SalePhase.Presale1) ||
                (phase == SalePhase.Publicsale &&
                    salePhase == SalePhase.Presale2) ||
                (phase == SalePhase.Ended && salePhase == SalePhase.Publicsale),
            "Invalid sale phase transition!"
        );
        salePhase = phase;
        tokenPrice = salePhases[phase].price;
    }

    function buyToken(
        uint256 usdtAmount,
        uint256 bnbPrice_
    ) external payable onlyDuringICO nonReentrant {
        require(
            salePhase != SalePhase.notStarted &&
                salePhase != SalePhase.Pause &&
                salePhase != SalePhase.Ended,
            "No active sale phase"
        );

        SalePhaseInfo storage currentPhase = salePhases[salePhase];
        uint256 tokenAmount;
        uint256 currentTime = block.prevrandao;
        uint256 unlockTime = currentTime + currentPhase.lockingPeriod;

        if (msg.value > 0) {
            // **BNB Payment**

            tokenAmount = (msg.value * 10 ** 18) / bnbPrice_;
            require(
                currentPhase.allocatedSupply >= tokenAmount,
                "Insufficient allocated tokens"
            );
        } else {
            // **USDT Payment**
            require(usdtAmount > 10, "Minimum purchase amount is 10 USDT");
            tokenAmount = (usdtAmount * 10 ** 18) / currentPhase.price;
            require(
                currentPhase.allocatedSupply >= tokenAmount,
                "Insufficient allocated tokens"
            );

            usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        }

        require(balanceOf(owner()) >= tokenAmount, "Not enough tokens");

        lockingBalances[msg.sender].push(
            LockingSchedule({
                amount: tokenAmount,
                purchaseTime: currentTime,
                phase: salePhase,
                unlockTime: unlockTime
            })
        );

        phaseBuyers[salePhase].push(msg.sender);
        soldTokens += tokenAmount;
        currentPhase.allocatedSupply -= tokenAmount;

        // Transfer tokens immediately
        _transfer(owner(), msg.sender, tokenAmount);

        userDetails[msg.sender].saleType = uint256(salePhase);
        userDetails[msg.sender].totalTokens += tokenAmount;

        emit TokenBought(
            msg.sender,
            usdtAmount > 0 ? usdtAmount : msg.value,
            tokenAmount,
            unlockTime
        );
    }

    function claimTokens() external nonReentrant {
        LockingSchedule[] storage schedules = lockingBalances[msg.sender];
        uint256 totalClaimable = 0;
        for (uint256 i = 0; i < schedules.length; i++) {
            if (
                schedules[i].amount > 0 &&
                block.timestamp >= schedules[i].unlockTime
            ) {
                totalClaimable += schedules[i].amount;
                schedules[i].amount = 0; // Mark as claimed/unlocked
            }
        }
        require(totalClaimable > 0, "No unlocked tokens to claim");
        emit TokensClaimed(msg.sender, totalClaimable);
    }

    function availableBalance(address account) public view returns (uint256) {
        uint256 locked = 0;
        LockingSchedule[] memory schedules = lockingBalances[account];
        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].amount > 0) {
                locked += schedules[i].amount;
            }
        }
        return balanceOf(account) - locked;
    }

    function checkStatus() external view returns (string memory) {
        if (manualPause) return "ICO is manually paused by owner";
        if (icoStart == 0 || icoEnd == 0) return "ICO has not started yet";
        if (block.timestamp >= icoStart && block.timestamp <= icoEnd)
            return "ICO is active";
        if (block.timestamp > icoEnd) return "ICO has ended";
        return "ICO has not started yet";
    }

    // Override transfer to ensure locked tokens cannot be transferred.
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            availableBalance(msg.sender) >= amount,
            "Insufficient unlocked balance because you have not claimed yet"
        );
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            availableBalance(sender) >= amount,
            "You tokens are still locked or you haven't claimed yet"
        );
        return super.transferFrom(sender, recipient, amount);
    }

    function transferWithLock(
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(balanceOf(owner()) >= amount, "Not enough tokens");
        _transfer(owner(), address(this), amount);

        vestingSchedules[recipient] = VestingSchedule({
            totalAmount: amount,
            claimedAmount: 0,
            lockEndTime: block.timestamp + lockDuration,
            unlockPerBatch: (amount * 20) / 100
        });
    }

    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No tokens allocated for vesting");
        require(
            block.timestamp >= schedule.lockEndTime,
            "Lock period is still active"
        );

        uint256 unlocked = getUnlockedTokens(msg.sender);
        require(unlocked > 0, "No vested tokens available to claim");

        schedule.claimedAmount += unlocked;
        _transfer(address(this), msg.sender, unlocked);
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 unlockedBalance = super.balanceOf(account);
        // If there is a vesting schedule, include the locked tokens.
        VestingSchedule storage schedule = vestingSchedules[account];
        uint256 lockedTokens = 0;
        if (schedule.totalAmount > 0) {
            lockedTokens = schedule.totalAmount - schedule.claimedAmount;
        }
        return unlockedBalance + lockedTokens;
    }

    function getLockedTokens(address user) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user];
        if (block.timestamp < schedule.lockEndTime) {
            return schedule.totalAmount;
        }

        // Calculate total intervals that have passed since lock end.
        uint256 intervalsPassed = (block.timestamp - schedule.lockEndTime) /
            vestingInterval;
        uint256 totalUnlocked = intervalsPassed * schedule.unlockPerBatch;
        if (totalUnlocked > schedule.totalAmount) {
            totalUnlocked = schedule.totalAmount;
        }
        return schedule.totalAmount - totalUnlocked;
    }

    function getUnlockedTokens(address user) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user];

        if (block.timestamp < schedule.lockEndTime) {
            return 0;
        }

        uint256 intervalsPassed = (block.timestamp - schedule.lockEndTime) /
            vestingInterval;
        uint256 totalUnlocked = intervalsPassed * schedule.unlockPerBatch;

        if (totalUnlocked > schedule.totalAmount) {
            totalUnlocked = schedule.totalAmount;
        }

        return totalUnlocked - schedule.claimedAmount;
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

    // this function is callable by backend
    function TransferRewards(
        address recipient_,
        uint256 amount_,
        uint256 lockTime_
    ) public onlyOwner {
        require(recipient_ != address(0), "recipient address is not valid");
        require(amount_ > 0, "amount should be > 0");
        require(lockTime_ > 0, "lock time should in future");
        require(
            balanceOf(owner()) >= amount_,
            "owner doesn't have enough tokens"
        );

        _transfer(msg.sender, recipient_, amount_);

        lockingBalances[recipient_].push(
            LockingSchedule({
                amount: amount_,
                purchaseTime: block.timestamp,
                phase: SalePhase.Ended,
                unlockTime: block.timestamp + lockTime_
            })
        );
    }
}
