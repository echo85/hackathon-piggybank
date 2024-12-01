// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PiggyBankOFT} from "../src/PiggyBankOFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console2.sol";
import {IStakedUSDe} from "src/interfaces/USDe/IStakedUSDe.sol";

contract EthenaTest is Test {
    PiggyBankOFT public piggy;
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public ownderSUSDe = 0x1B6877c6Dac4b6De4c5817925DC40E2BfdAFc01b; //not sure what is the owner of sUSDe on sepolia

    uint256 public MAX_BPS = 10_000;

    bytes32 private constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    // Fuzz from $0.01 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 500000 * 1e18;
    uint256 public minFuzzAmount = 100 * 1e18;
    ERC20 public asset;
    address public base;
    address public from;
    address public erc20;
    address vault;
    uint24 public constant poolFee1 = 100;
    uint24 public constant poolFee3 = 300;

    function setUp() public {
        vm.prank(management);
        asset = ERC20(0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE); // USDE 
        vault = 0x80f9Ec4bA5746d8214b3A9a73cc4390AB0F0E633; // SUDSE 
        base = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE; // USDE as BASE
        erc20 = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE; // PIGGY TOKEN as ERC20
        address pythAddress = 0x2880aB155794e7179c9eE2e38200202908C17B43;
        bytes32 priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d;
        address uniswapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E; // UNISWAP ROUTER
    
        piggy = new PiggyBankOFT(asset, management, keeper, vault, erc20, pythAddress, priceFeedIdUSDe, uniswapRouter);

        vm.prank(management);
        piggy.setBase(address(base));

        vm.prank(management);
        piggy.setUniFees(address(asset),base,poolFee3);
        
        vm.prank(management);
        piggy.setUniFees(base,erc20,poolFee3);

        vm.prank(management);
        piggy.setUniFees(erc20,address(asset),poolFee3);
        console2.log("contract deployed", address(piggy));
        
    }

    function test_deposit(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount", _amount);

        // Deposit USDe into Piggy
        uint256 balanceBefore = asset.balanceOf(user);
        deal(address(asset), user, balanceBefore + _amount);

        vm.prank(user);
        asset.approve(address(piggy), _amount);

        vm.prank(user);
        piggy.deposit(_amount, user);
        
        console2.log("Balance of user asset", asset.balanceOf(user));
        console2.log("Balance of user piggy", piggy.balanceOf(user));
        console2.log("Total assets on piggy", piggy.totalAssets());

    }

    function test_unstake(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount", _amount);

        // Deposit USDe into Piggy
        uint256 balanceBefore = asset.balanceOf(user);
        deal(address(asset), user, balanceBefore + _amount);

        vm.prank(user);
        asset.approve(address(piggy), _amount);

        vm.prank(user);
        uint256 pUSDeAmount = piggy.deposit(_amount, user);
        
        console2.log("Balance of user asset", asset.balanceOf(user));
        console2.log("Balance of user piggy", piggy.balanceOf(user));
        console2.log("Total assets on piggy", piggy.totalAssets());

        vm.prank(user);
        piggy.cooldownShares(pUSDeAmount);
        
        skip(7 days);
        vm.prank(user);
        piggy.unstake(user);
    }
   

}
