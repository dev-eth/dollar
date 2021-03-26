pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./oracle/Oracle.sol";
import "./Constants.sol";

interface StakedToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface RewardToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Staking is Constants, Ownable, Oracle, ReentrancyGuard {

    struct User {
        uint256 depositAmount;
        uint256 paidReward;

        uint256 deoxReward;
        uint256 deaReward;
        uint256 usdcReward;
    }

    using SafeMath for uint256;

    mapping (address => User) public users;
    mapping (address => uint256) public userRewardPerTokenPaid;
    mapping (address => uint256) public rewards;
    mapping (address => uint256) private _balances;

    uint256 public totalAmount = 0; // This public variable will be used to calculate the total deposit amount, can be called by another contracts
    uint256 public rewardTillNowPerToken = 0;
    uint256 public lastUpdatedBlock;
    uint256 public rewardPerBlock;
    uint256 public scale = 1e18;

    uint256 public periodFinish = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardRate = 0;
    uint256 public rewardPerTokenStored;

    uint256 public rewardUsdc;
    uint256 public rewardDea;
    uint256 public rewardDeox;

    uint256 private _totalSupply;

    StakedToken public stakedToken;
    RewardToken public rewardToken;

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event EmergencyWithdraw(address user, uint256 amount);
    event RewardClaimed(address user, uint256 amount);
    event RewardPerBlockChanged(uint256 oldValue, uint256 newValue);
    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);

    constructor (address _stakedToken, address _rewardToken, uint256 _rewardPerBlock) public {
        stakedToken = StakedToken(_stakedToken);
        rewardToken = RewardToken(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        lastUpdatedBlock = block.number;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return 
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(CURRENT_EPOCH_PERIOD);
    }

    function notifyRewardAmount(uint256 _rewardUsdc, uint256 _rewardDea, uint256 _rewardDeox) public updateReward(address(0)) {
        uint256 reward = 10 ** 18;

        rewardUsdc = _rewardUsdc;
        rewardDea = _rewardDea;
        rewardDeox = _rewardDeox;

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(CURRENT_EPOCH_PERIOD);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(CURRENT_EPOCH_PERIOD);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardToken.balanceOf(address(this));
        require(rewardRate <= balance.div(CURRENT_EPOCH_PERIOD), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(CURRENT_EPOCH_PERIOD);
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        update();
        emit RewardPerBlockChanged(rewardPerBlock, _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
    }

    // Update reward variables of the pool to be up-to-date.
    function update() public {
        if (block.number <= lastUpdatedBlock) {
            return;
        }
        uint256 totalStakedToken = stakedToken.balanceOf(address(this));
        uint256 rewardAmount = (block.number - lastUpdatedBlock).mul(rewardPerBlock);

        rewardTillNowPerToken = rewardTillNowPerToken.add(rewardAmount.mul(scale).div(totalStakedToken));
        lastUpdatedBlock = block.number;
    }

    // View function to see pending reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        User storage user = users[_user];
        uint256 accRewardPerToken = rewardTillNowPerToken;

        if (block.number > lastUpdatedBlock) {
            uint256 totalStakedToken = stakedToken.balanceOf(address(this));
            uint256 rewardAmount = (block.number - lastUpdatedBlock).mul(rewardPerBlock);
            accRewardPerToken = accRewardPerToken.add(rewardAmount.mul(scale).div(totalStakedToken));
        }
        return user.depositAmount.mul(accRewardPerToken).div(scale).sub(user.paidReward);
    }

    function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
        // Users will only deposit when TWAP price is below 1 usd
        (Decimal.D256 memory price, bool valid) = capture();
        require(price.greaterThan(Decimal.twap1()), "Deposit is unavailable!");

        User storage user = users[msg.sender];
        update();

        // We should calculate the total deposit amount
        totalAmount += user.depositAmount;

        if (user.depositAmount > 0) {
            uint256 _pendingReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale).sub(user.paidReward);
            rewardToken.transfer(msg.sender, _pendingReward);
            emit RewardClaimed(msg.sender, _pendingReward);
        }

        user.depositAmount = user.depositAmount.sub(amount);
        user.paidReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale);

        stakedToken.transferFrom(address(msg.sender), address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        User storage user = users[msg.sender];

        // Users will only redeem when TWAP price is above 1 usd
        (Decimal.D256 memory price, bool valid) = capture();
        require(price.lessThan(Decimal.twap2()), "Redeem is unavailable!");

        require(user.depositAmount >= amount, "withdraw amount exceeds deposited amount");
        update();

        uint256 _pendingReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale).sub(user.paidReward);

        rewardToken.transfer(msg.sender, _pendingReward * 10 ** 18 / rewardUsdc);
        rewardToken.transfer(msg.sender, _pendingReward * 10 ** 18 / rewardDea);
        rewardToken.transfer(msg.sender, _pendingReward * 10 ** 18 / rewardDeox);
        
        emit RewardClaimed(msg.sender, _pendingReward);

        if (amount > 0) {
            user.depositAmount = user.depositAmount.sub(amount);
            stakedToken.transfer(address(msg.sender), amount);
            emit Withdraw(msg.sender, amount);
        }

        user.paidReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    // End rewards emission earlier
    function updatePeriodFinish(uint timestamp) external onlyOwner updateReward(address(0)) {
        periodFinish = timestamp;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        User storage user = users[msg.sender];

        stakedToken.transfer(msg.sender, user.depositAmount);

        emit EmergencyWithdraw(msg.sender, user.depositAmount);

        user.depositAmount = 0;
        user.paidReward = 0;
    }

    // Add temporary withdrawal functionality for owner(DAO) to transfer all tokens to a safe place.
    // Contract ownership will transfer to address(0x) after full auditing of codes.
    function withdrawAllRewardTokens(address to) public onlyOwner {
        uint256 totalRewardTokens = rewardToken.balanceOf(address(this));
        rewardToken.transfer(to, totalRewardTokens);
    }

    // Add temporary withdrawal functionality for owner(DAO) to transfer all tokens to a safe place.
    // Contract ownership will transfer to address(0x) after full auditing of codes.
    function withdrawAllStakedtokens(address to) public onlyOwner {
        uint256 totalStakedTokens = stakedToken.balanceOf(address(this));
        stakedToken.transfer(to, totalStakedTokens);
    }
}
