// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PiggyBankOFT} from "../src/PiggyBankOFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyEthenaScript is Script {
    PiggyBankOFT public piggy;
    uint24 public constant poolFee1 = 100;
    uint24 public constant poolFee3 = 300;

    // SEPOLIA Address NO POOL FOR SEPOLIA
    address public constant asset = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE; // USDE 
    address public constant vault = 0x80f9Ec4bA5746d8214b3A9a73cc4390AB0F0E633; // SUDSE 
    address public constant base = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE; // using USDE as base
    address public constant erc20 = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE; // using USDE AS ERC20
    address public constant pythAddress = 0x2880aB155794e7179c9eE2e38200202908C17B43; //PYTH 
    bytes32 public constant priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d;
    bytes32 public constant priceFeedIdERC20 = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d; // WETH/USD     
    address public constant uniswapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E; // UNISWAP ROUTER
    
    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address management = vm.addr(deployerPrivateKey);
        address keeper = management;
        
        vm.startBroadcast(deployerPrivateKey); 
        piggy = new PiggyBankOFT(ERC20(asset), management, keeper, vault, erc20, pythAddress, priceFeedIdUSDe, uniswapRouter);

        piggy.setBase(address(base));
        piggy.updateERC20(erc20, priceFeedIdERC20);
        piggy.setUniFees(address(asset),base,poolFee1);
        piggy.setUniFees(base,erc20,poolFee1);
        piggy.setUniFees(erc20,address(asset),poolFee1);

        console.log("contract deployed", address(piggy));
        vm.stopBroadcast();

        
    }
}
