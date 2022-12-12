
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Pool {

    uint256 settlementDate;
    int256 price;
    address oracleAddress;

    bool condition;

    function getCondition() public view returns (bool){
        return(condition);
    }

    function pastSettlementDate() public view returns (bool){
        return(block.timestamp > settlementDate);
    }

    POS public positiveSide;
    NEG public negativeSide;

    AggregatorV3Interface public oracle;

    constructor(address _oracle, int256 _price, uint256 _settlementDate) {
        settlementDate = _settlementDate;
        price = _price;
        oracleAddress = _oracle;

        positiveSide = new POS("OVER");
        negativeSide = new NEG("UNDER");
        condition = false;

        oracle = AggregatorV3Interface(oracleAddress);
    }

    function depositToPOS() public payable {
        require(block.timestamp < settlementDate);
        require(msg.value > 0.001 ether, "mc");
        positiveSide.mint(msg.value);
        positiveSide.transfer(msg.sender,msg.value);
    }

    function depositToNEG() public payable {
        require(block.timestamp < settlementDate);
        require(msg.value > 0.001 ether, "mc");
        negativeSide.mint(msg.value);
        negativeSide.transfer(msg.sender,msg.value);

    }

    function settle() public {
        require(block.timestamp > settlementDate, "te");
        (,int256 resultPrice,,,) = oracle.latestRoundData();

        if(resultPrice >= price){
            condition = true;
        }

    }

    function withdrawWithPOS() public { 
        require(block.timestamp > settlementDate, "te");
        require(condition == true,"cn");
        require(positiveSide.balanceOf(msg.sender) > 0, "yn");

        uint256 saved = (positiveSide.balanceOf(msg.sender) / positiveSide.totalSupply()) * (address(this).balance);
        
        positiveSide.transferFrom(msg.sender,address(this),positiveSide.balanceOf(msg.sender));

        (payable(msg.sender)).transfer(saved);
    }

    function withdrawWithNEG() public {
        require(block.timestamp > settlementDate, "te");
        require(condition == false,"cn");
        require(negativeSide.balanceOf(msg.sender) > 0, "yn");

        uint256 saved = (negativeSide.balanceOf(msg.sender) / negativeSide.totalSupply()) * (address(this).balance);
        
        negativeSide.transferFrom(msg.sender,address(this),negativeSide.balanceOf(msg.sender));

        (payable(msg.sender)).transfer(saved);
    }
}


// contract useChainLink {
    
//     AggregatorV3Interface public priceFeed;
//     address public owner;

//     constructor(address _oracle) {
//         priceFeed = AggregatorV3Interface(_oracle);
//     }

//     function getLatestPrice() public view returns (int){
//         (,int price,,,) = priceFeed.latestRoundData();
//         return(price);
//     }
// }

contract POS is ERC20, Ownable {
    constructor(string memory name) ERC20(name,"POS") {
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender,amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender,amount);
    }
}

contract NEG is ERC20, Ownable {
    constructor(string memory name) ERC20(name,"NEG") {
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender,amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender,amount);
    }
}

contract deploy {

    event PoolCreated(address _oracle, int256 _price, uint256 _settlementDate,address poolAddress);

    function createPool(address oracle, int256 price, uint256 settlementDate) public returns (address newPool){
        newPool = address(new Pool(oracle,price,settlementDate));
        emit PoolCreated(oracle,price,settlementDate,newPool);
        return(newPool);
    }
}
