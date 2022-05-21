//SPDX Licence-Identifier: MIT;
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/vendor/SafeMathChainlink.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {

  using SafeMathChainlink for uint256;

  enum LOTTERY_STATE {OPEN, CLOSED, CALCULATING_WINNER}
  LOTTERY_STATE public lotteryState;
  AggregatorV3Interface internal ethUsdPriceFeed;
  uint256 public usdEntryFee;
  address payable[] public players;
  address public recentWinner;
  uint256 public randomness;
  uint256 fee;
  bytes32 public keyHash; 

  event RequestedRandomness(bytes32 requestId);

  mapping(address => uint256) ethBalance;

  constructor(address _ethUsdPriceFeed, address _vrfCoordinator, address _link, bytes32 _keyHash) public 
  VRFConsumerBase(
      _vrfCoordinator,
      _link

    ){

    ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    usdEntryFee = 50;
    lotteryState = LOTTERY_STATE.CLOSED;
    fee = 100000000000000000; //0.1 LINK
    keyHash = _keyHash;
  }
  function depositEth() public payable{
    ethBalance[msg.sender] += msg.value;
  }

  function enter() public payable {
    require(ethBalance[msg.sender] >= getEntranceFee(), "Not enough balance to enter!");
    require(lotteryState == LOTTERY_STATE.OPEN);
    players.push(msg.sender);
  }

  function getEntranceFee() public view returns(uint256){
    uint256 precision = 1 * 10 **18; // This is 1 ETH in wei
    uint256 price = getLatestEthUsdPrice(); // This is the current USD value for 1 ETH
    uint256 costToEnter = (precision / price ) * (usdEntryFee * 100000000); // ( 1ETH in Wei / dollar in ETH ) * (50 * 100000000)
    return costToEnter;

  }
 
  function getLatestEthUsdPrice() public view returns(uint256){
            (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound 
        ) = ethUsdPriceFeed.latestRoundData();
        return uint256(price);

  }

  function startLottery() public onlyOwner {
    require(lotteryState == LOTTERY_STATE.CLOSED, "Cannot start a new Lottery until current one finished");
    lotteryState = LOTTERY_STATE.OPEN;
    randomness = 0;
  }


  function endLottery(uint256 userProvidedSeed) public onlyOwner{
    require(lotteryState == LOTTERY_STATE.OPEN, "Lottery has to be open in order to calculate a winner");
    lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
    pickWinner(userProvidedSeed);

  }



  function pickWinner(uint256 userProvidedSeed) private returns(bytes32) {
    require(lotteryState == LOTTERY_STATE.CALCULATING_WINNER, "needs to be claculating the winner");
    bytes32 requestId = requestRandomness(keyHash, fee);
    emit RequestedRandomness(requestId);

  } 
  function fulfillRandomness(bytes32 requestId, uint256 randomness) override internal {
        require(randomness > 0, "random number must be higher than 0");
        uint256 index = randomness % players.length; // This is how we set the random number generator to do not make that much of a number, just how many players we have
        players[index].transfer(address(this).balance); // Send the winner all the Ethereum address to this smart contract
        players = new address payable[](0);
        recentWinner = players[index];
        lotteryState = LOTTERY_STATE.CLOSED;
        randomness = randomness;
  }

}