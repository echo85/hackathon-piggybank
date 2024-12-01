// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PiggyBank} from "../src/PiggyBank.sol";
import {PiggyBankOFTAdapter} from "../src/PiggyBankOFTAdapter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggySepoliaScript is Script {
    PiggyBank public piggy;
    uint24 public constant poolFee1 = 100;
    uint24 public constant poolFee3 = 300;
    PiggyBankOFTAdapter piggyOFTAdapter;

    // SEPOLIA Address NO POOL FOR SEPOLIA
    address public constant asset = 0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696; // USDE 
    address public constant vault = 0x1B6877c6Dac4b6De4c5817925DC40E2BfdAFc01b; // SUDSE 
    address public constant base = 0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696; // USDE as BASE
    address public constant erc20 = 0x6296665981B7bf5E39B8b7a1021692289212825A; // PIG TOKEN
    address public constant pythAddress = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729; //PYTH 
    bytes32 public constant priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d;
    bytes32 public constant priceFeedIdERC20 = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d; // using USDe    
    address public constant uniswapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E; // UNISWAP ROUTER
    address public constant endpointV2address = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    
    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address management = vm.addr(deployerPrivateKey);
        address keeper = management;
        
        vm.startBroadcast(deployerPrivateKey); 
        piggy = new PiggyBank(ERC20(asset), management, keeper, vault, erc20, pythAddress, priceFeedIdUSDe, uniswapRouter);

        piggy.setBase(address(base));
        piggy.updateERC20(erc20, priceFeedIdERC20);
        piggy.setUniFees(address(asset),base,poolFee3);
        piggy.setUniFees(base,erc20,poolFee3);
        piggy.setUniFees(erc20,address(asset),poolFee3);

        piggyOFTAdapter = new PiggyBankOFTAdapter(address(piggy),endpointV2address,management);

        console.log("contract deployed", address(piggy));
        vm.stopBroadcast();

        
    }
}
