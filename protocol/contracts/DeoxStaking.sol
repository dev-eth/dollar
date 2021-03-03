pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./oracle/Oracle.sol";

interface StakedToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface RewardToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Staking is Ownable, Oracle {

    struct User {
        uint256 depositAmount;
        uint256 paidReward;
        uint256 totalBurntDeoxAmount;
    }

    using SafeMath for uint256;

    mapping (address => User) public users;

    uint256 public totalAmount; // This public variable will be used to calculate the total deposit amount, can be called by another contracts
    uint256 public rewardTillNowPerToken = 0;
    uint256 public lastUpdatedBlock;
    uint256 public rewardPerBlock;
    uint256 public scale = 1e18;

    uint256 public particleCollector = 0;
    uint256 public daoShare;
    uint256 public earlyFoundersShare;
    address public daoWallet;
    address public earlyFoundersWallet;

    StakedToken public stakedToken;
    RewardToken public rewardToken;

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event EmergencyWithdraw(address user, uint256 amount);
    event RewardClaimed(address user, uint256 amount);
    event RewardPerBlockChanged(uint256 oldValue, uint256 newValue);

    constructor (address _stakedToken, address _rewardToken, uint256 _rewardPerBlock, uint256 _daoShare, uint256 _earlyFoundersShare) public {
        stakedToken = StakedToken(_stakedToken);
        rewardToken = RewardToken(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        daoShare = _daoShare;
        earlyFoundersShare = _earlyFoundersShare;
        lastUpdatedBlock = block.number;
        daoWallet = msg.sender;
        earlyFoundersWallet = msg.sender;
    }

    function setWallets(address _daoWallet, address _earlyFoundersWallet) public onlyOwner {
        daoWallet = _daoWallet;
        earlyFoundersWallet = _earlyFoundersWallet;
    }

    function setShares(uint256 _daoShare, uint256 _earlyFoundersShare) public onlyOwner {
        withdrawParticleCollector();
        daoShare = _daoShare;
        earlyFoundersShare = _earlyFoundersShare;
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

    function deposit(uint256 amount) public {
        // Users will only deposit when TWAP price is below 1 usd
        (Decimal.D256 memory price, bool valid) = capture();
        require(price.greaterThan(Decimal.one()), "Deposit is unavailable!");

        // We should burn the deox when users deposit them to the Staking contract
        stakedToken.transfer(address(0), amount);

        User storage user = users[msg.sender];
        update();

        // We should store the total burnt deox amount
        user.totalBurntDeoxAmount += amount;
        // We should calculate the total deposit amount
        totalAmount += user.depositAmount;

        if (user.depositAmount > 0) {
            uint256 _pendingReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale).sub(user.paidReward);
            rewardToken.transfer(msg.sender, _pendingReward);
            emit RewardClaimed(msg.sender, _pendingReward);
        }

        // We don't need the below code as we burnt the deox amount when the users deposit
        // user.depositAmount = user.depositAmount.sub(amount);
        // user.paidReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale);

        // stakedToken.transferFrom(address(msg.sender), address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        User storage user = users[msg.sender];
        require(user.depositAmount >= amount, "withdraw amount exceeds deposited amount");
        update();

        uint256 _pendingReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale).sub(user.paidReward);
        rewardToken.transfer(msg.sender, _pendingReward);
        emit RewardClaimed(msg.sender, _pendingReward);

        uint256 particleCollectorShare = _pendingReward.mul(daoShare.add(earlyFoundersShare)).div(scale);
        particleCollector = particleCollector.add(particleCollectorShare);

        if (amount > 0) {
            user.depositAmount = user.depositAmount.sub(amount);
            stakedToken.transfer(address(msg.sender), amount);
            emit Withdraw(msg.sender, amount);
        }

        user.paidReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale);
    }

    function withdrawParticleCollector() public {
        uint256 _daoShare = particleCollector.mul(daoShare).div(daoShare.add(earlyFoundersShare));
        rewardToken.transfer(daoWallet, _daoShare);

        uint256 _earlyFoundersShare = particleCollector.mul(earlyFoundersShare).div(daoShare.add(earlyFoundersShare));
        rewardToken.transfer(earlyFoundersWallet, _earlyFoundersShare);

        particleCollector = 0;
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
