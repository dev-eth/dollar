/*
    Copyright 2020 Empty Set Squad <emptysetsquad@protonmail.com>

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "./external/Decimal.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract Constants {
    /* Chain */
    uint256 private CHAIN_ID = 1; // Mainnet

    /* Bootstrapping */
    uint256 public BOOTSTRAPPING_PERIOD = 90;
    uint256 public BOOTSTRAPPING_PRICE = 11e17; // 1.10 USDC
    uint256 public BOOTSTRAPPING_SPEEDUP_FACTOR = 3; // 30 days @ 8 hours

    /* Oracle */
    address private constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC token address

    uint256 public ORACLE_RESERVE_MINIMUM = 1e10; // 10,000 USDC

    /* Bonding */
    uint256 public INITIAL_STAKE_MULTIPLE = 1e6; // 100 ESD -> 100M ESDS

    /* Epoch */
    struct EpochStrategy {
        uint256 offset;
        uint256 start;
        uint256 period;
    }

    uint256 public PREVIOUS_EPOCH_OFFSET = 91;
    uint256 public PREVIOUS_EPOCH_START = 1600905600;
    uint256 public PREVIOUS_EPOCH_PERIOD = 86400;

    uint256 public CURRENT_EPOCH_OFFSET = 106;
    uint256 public CURRENT_EPOCH_START = 1602201600;
    uint256 public CURRENT_EPOCH_PERIOD = 28800;

    /* DAO */
    uint256 public ADVANCE_INCENTIVE = 1e20; // 100 ESD
    uint256 public DAO_EXIT_LOCKUP_EPOCHS = 15; // 15 epochs fluid

    /* Pool */
    uint256 public POOL_EXIT_LOCKUP_EPOCHS = 5; // 5 epochs fluid

    /* Market */
    uint256 public COUPON_EXPIRATION = 441;
    uint256 public DEBT_RATIO_CAP = 20e16; // 20%

    /* Regulator */
    uint256 public SUPPLY_CHANGE_LIMIT = 3e16; // 3%
    uint256 public COUPON_SUPPLY_CHANGE_LIMIT = 6e16; // 6%
    uint256 public ORACLE_POOL_RATIO = 20; // 20%
    uint256 public TREASURY_RATIO = 4000; // 40% Change the treasury ratio from 2.5% to 40%

    /* Deployed */
    address private constant DAO_ADDRESS = address(0x443D2f2755DB5942601fa062Cc248aAA153313D3);
    address private constant DOLLAR_ADDRESS = address(0x36F3FD68E7325a35EB768F1AedaAe9EA0689d723);
    address private constant PAIR_ADDRESS = address(0x88ff79eB2Bc5850F27315415da8685282C7610F9);
    address public TREASURY_ADDRESS = address(0x460661bd4A5364A3ABCc9cfc4a8cE7038d05Ea22); // This should be the Depot Controller Contract Address

    /**
     * Getters
    */

    function getUsdcAddress() internal view returns (address) {
        return USDC;
    }

    function getOracleReserveMinimum() internal view returns (uint256) {
        return ORACLE_RESERVE_MINIMUM;
    }

    function getPreviousEpochStrategy() internal view returns (EpochStrategy memory) {
        return EpochStrategy({
            offset: PREVIOUS_EPOCH_OFFSET,
            start: PREVIOUS_EPOCH_START,
            period: PREVIOUS_EPOCH_PERIOD
        });
    }

    function getCurrentEpochStrategy() internal view returns (EpochStrategy memory) {
        return EpochStrategy({
            offset: CURRENT_EPOCH_OFFSET,
            start: CURRENT_EPOCH_START,
            period: CURRENT_EPOCH_PERIOD
        });
    }

    function getInitialStakeMultiple() internal view returns (uint256) {
        return INITIAL_STAKE_MULTIPLE;
    }

    function getBootstrappingPeriod() internal view returns (uint256) {
        return BOOTSTRAPPING_PERIOD;
    }

    function getBootstrappingPrice() internal view returns (Decimal.D256 memory) {
        return Decimal.D256({value: BOOTSTRAPPING_PRICE});
    }

    function getBootstrappingSpeedupFactor() internal view returns (uint256) {
        return BOOTSTRAPPING_SPEEDUP_FACTOR;
    }

    function getAdvanceIncentive() internal view returns (uint256) {
        return ADVANCE_INCENTIVE;
    }

    function getDAOExitLockupEpochs() internal view returns (uint256) {
        return DAO_EXIT_LOCKUP_EPOCHS;
    }

    function getPoolExitLockupEpochs() internal view returns (uint256) {
        return POOL_EXIT_LOCKUP_EPOCHS;
    }

    function getCouponExpiration() internal view returns (uint256) {
        return COUPON_EXPIRATION;
    }

    function getDebtRatioCap() internal view returns (Decimal.D256 memory) {
        return Decimal.D256({value: DEBT_RATIO_CAP});
    }

    function getSupplyChangeLimit() internal view returns (Decimal.D256 memory) {
        return Decimal.D256({value: SUPPLY_CHANGE_LIMIT});
    }

    function getCouponSupplyChangeLimit() internal view returns (Decimal.D256 memory) {
        return Decimal.D256({value: COUPON_SUPPLY_CHANGE_LIMIT});
    }

    function getOraclePoolRatio() internal view returns (uint256) {
        return ORACLE_POOL_RATIO;
    }

    function getTreasuryRatio() internal view returns (uint256) {
        return TREASURY_RATIO;
    }

    function getChainId() internal view returns (uint256) {
        return CHAIN_ID;
    }

    function getDaoAddress() internal view returns (address) {
        return DAO_ADDRESS;
    }

    function getDollarAddress() internal view returns (address) {
        return DOLLAR_ADDRESS;
    }

    function getPairAddress() internal view returns (address) {
        return PAIR_ADDRESS;
    }

    function getTreasuryAddress() internal view returns (address) {
        return TREASURY_ADDRESS;
    }

    /**
     * Setters
    */

    function setBootstrappingPeriod (uint256 _period) public returns (uint256) {
        BOOTSTRAPPING_PERIOD = _period;
    }

    function setBootstrappingPrice (uint256 _price) public returns (uint256) {
        BOOTSTRAPPING_PRICE = _price;
    }

    function setBootstrappingSpeedupFactor (uint256 _speed) public returns (uint256) {
        BOOTSTRAPPING_SPEEDUP_FACTOR = _speed;
    }

    function setOracleReserveMinimum (uint256 _reserveMinimum) public returns (uint256) {
        ORACLE_RESERVE_MINIMUM = _reserveMinimum;
    }

    function setInitialStakeMultiple (uint256 _initialStake) public returns (uint256) {
        INITIAL_STAKE_MULTIPLE = _initialStake;
    }

    function setPreviousEpochOffset (uint256 _previousOffset) public returns (uint256) {
        PREVIOUS_EPOCH_OFFSET = _previousOffset;
    }

    function setPreviousEpochStart (uint256 _previousStart) public returns (uint256) {
        PREVIOUS_EPOCH_START = _previousStart;
    }

    function setPreviousEpochPeriod (uint256 _previousPeriod) public returns (uint256) {
        PREVIOUS_EPOCH_PERIOD = _previousPeriod;
    }

    function setCurrentEpochOffset (uint256 _currentOffset) public returns (uint256) {
        CURRENT_EPOCH_OFFSET = _currentOffset;
    }

    function setCurrentEpochStart (uint256 _currentStart) public returns (uint256) {
        CURRENT_EPOCH_START = _currentStart;
    }

    function setCurrentEpochPeriod (uint256 _currentPeriod) public returns (uint256) {
        CURRENT_EPOCH_PERIOD = _currentPeriod;
    }

    function setAdvanceIncentive (uint256 _advance) public returns (uint256) {
        ADVANCE_INCENTIVE = _advance;
    }

    function setDaoExitLockup (uint256 _daoExit) public returns (uint256) {
        DAO_EXIT_LOCKUP_EPOCHS = _daoExit;
    }

    function setPoolExitLockup (uint256 _poolExit) public returns (uint256) {
        POOL_EXIT_LOCKUP_EPOCHS = _poolExit;
    }

    function setCouponExpiration (uint256 _couponExpire) public returns (uint256) {
        COUPON_EXPIRATION = _couponExpire;
    }

    function setDebtRatioCap (uint256 _debtRatioCap) public returns (uint256) {
        DEBT_RATIO_CAP = _debtRatioCap;
    }

    function setSupplyChangeLimit (uint256 _supplyChangeLimit) public returns (uint256) {
        SUPPLY_CHANGE_LIMIT = _supplyChangeLimit;
    }

    function setCouponSupplyChangeLimit (uint256 _couponSupplyChangeLimit) public returns (uint256) {
        COUPON_SUPPLY_CHANGE_LIMIT = _couponSupplyChangeLimit;
    }

    function setOraclePoolRatio (uint256 _oraclePoolRatio) public returns (uint256) {
        ORACLE_POOL_RATIO = _oraclePoolRatio;
    }

    function setTreasuryRatio (uint256 _treasuryRatio) public returns (uint256) {
        TREASURY_RATIO = _treasuryRatio;
    }

    function setTreasuryAddress (address _treasuryAddress) public returns (address) {
        TREASURY_ADDRESS = _treasuryAddress;
    }
}
