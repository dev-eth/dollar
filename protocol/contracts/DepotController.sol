pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./oracle/Oracle.sol";
import "./Constants.sol";

contract DepotControl is Constants, Ownable, Oracle, ReentrancyGuard {

    using SafeMath for uint256;
    
}
