pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

interface StakedToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface RewardToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);

}

contract Staking is Ownable {

    struct User {
        uint256 depositAmount;
        uint256 paidReward;
    }

    using SafeMath for uint256;

    mapping (address => User) public users;

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

    function add(
            uint256 _rewardAllocation, 
            IERC20 _pairAddress, 
            IERC20 _otherToken
            ) external onlyOwner {
            require (_rewardAllocation <= 100, "Invalid allocation");
            uint256 _totalAllocation = rewardAllocation.mul(_rewardAllocation).div(100);
            for (uint256 pid = 0; pid < poolInfo.length; ++ pid) {
                _totalAllocation = _totalAllocation.add(poolInfo[pid].rewardAllocation);
            }
            require (_totalAllocation <= rewardAllocation, "Allocation exceeded");

            poolInfo.push(PoolInfo({
                pairAddress: _pairAddress,
                otherToken: _otherToken,
                rewardAllocation: rewardAllocation.mul(_rewardAllocation).div(100),
                borrowedSupply: 0,
                totalSupply: 0
            }));
        }

    function set(uint256 _poolId, uint256 _rewardAllocation) external onlyOwner {
            require (_rewardAllocation <= 100, "Invalid allocation");
            uint256 totalAllocation = rewardAllocation.sub(poolInfo[_poolId].rewardAllocation).add(
                rewardAllocation.mul(_rewardAllocation).div(100)
            );
            require (totalAllocation <= rewardAllocation, "Allocation exceeded");
            
            if (poolInfo[_poolId].rewardAllocation != rewardAllocation.mul(_rewardAllocation).div(100)) {
                poolInfo[_poolId].rewardAllocation = rewardAllocation.mul(_rewardAllocation).div(100);
            }
        }

    function deposit(uint256 amount) public {
        User storage user = users[msg.sender];
        update();

        if (user.depositAmount > 0) {
            uint256 _pendingReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale).sub(user.paidReward);
            rewardToken.transfer(msg.sender, _pendingReward);
            emit RewardClaimed(msg.sender, _pendingReward);
        }

        user.depositAmount = user.depositAmount.add(amount);
        user.paidReward = user.depositAmount.mul(rewardTillNowPerToken).div(scale);

        stakedToken.transferFrom(address(msg.sender), address(this), amount);
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
