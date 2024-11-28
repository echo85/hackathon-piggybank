// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Piggy} from "../src/Piggy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyScript is Script {
    Piggy public piggy;
    uint24 public constant poolFee1 = 100;
    uint24 public constant poolFee3 = 300;

    // MAINNET
    address public constant asset = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // USDE 
    address public constant vault = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // SUDSE 
    address public constant base = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
    address public constant erc20 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public constant pythAddress = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6; //PYTH 

    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address management = vm.addr(deployerPrivateKey);
        address keeper = management;
        
        vm.startBroadcast(deployerPrivateKey); 
        piggy = new Piggy(ERC20(asset), management, keeper, vault, erc20, pythAddress);

        piggy.setBase(address(base));
        piggy.setUniFees(address(asset),base,poolFee1);
        piggy.setUniFees(base,erc20,poolFee1);
        piggy.setUniFees(erc20,address(asset),poolFee1);

        console.log("contract deployed", address(piggy));
        vm.stopBroadcast();

        
    }
}
