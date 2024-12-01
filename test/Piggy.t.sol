// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PiggyBank} from "../src/PiggyBank.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console2.sol";
import {IStakedUSDe} from "src/interfaces/USDe/IStakedUSDe.sol";

contract PiggyTest is Test {
    PiggyBank public piggy;
    address public user = address(10);
    address public user2 = address(3);
    address public keeper = address(4);
    address public management = address(1);
    address public ownderSUSDe = 0x3B0AAf6e6fCd4a7cEEf8c92C32DFeA9E64dC1862;

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
        asset = ERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3); // USDE MAINNET
        vault = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // SUDSE MAINNET
        base = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        erc20 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        address pythAddress = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
        bytes32 priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d;
        address uniswapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // UNISWAP ROUTER
    
        piggy = new PiggyBank(asset, management, keeper, vault, erc20, pythAddress, priceFeedIdUSDe, uniswapRouter);

        vm.prank(management);
        piggy.setBase(address(base));

        vm.prank(management);
        piggy.setUniFees(address(asset),base,poolFee1);
        
        vm.prank(management);
        piggy.setUniFees(base,erc20,poolFee1);

        vm.prank(management);
        piggy.setUniFees(erc20,address(asset),poolFee1);
        console2.log("contract deployed", address(piggy));

        
    }

    function test_rewards(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount", _amount);

        _liquidity(_amount);

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

        skip(7 days);
        _earnRewards(_profitFactor);
        console2.log("Total assets on piggy after Rewards", piggy.totalAssets());
    }

    function _earnRewards(uint16 _profitFactor) internal {
         // Simulating transferInRewards() of USDe
        uint256 toAirdrop = (IStakedUSDe(vault).totalAssets() * _profitFactor) / MAX_BPS;
        //console2.log("Airdrop to sUSDe",toAirdrop);
        //console2.log("Total assets on sUSDe before", IStakedUSDe(vault).totalAssets());
        vm.prank(ownderSUSDe);
        IStakedUSDe(vault).grantRole(REWARDER_ROLE,ownderSUSDe);
        deal(address(asset), ownderSUSDe, toAirdrop); 
        
        //console2.log("Total assets on ownerSUSDe", asset.balanceOf(ownderSUSDe));
        vm.prank(ownderSUSDe);
        asset.approve(vault, toAirdrop);
        
        vm.prank(ownderSUSDe);
        IStakedUSDe(vault).transferInRewards(toAirdrop);
        skip(10 hours); // because the VESTING_PERIOD is 8 hours
        //console2.log("Total assets on sUSDe after", IStakedUSDe(vault).totalAssets());
    }

   function test_harvest(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount of USDe", _amount);

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

        _harvest(_profitFactor);
    }

    
    function _harvest(uint16 _profitFactor) internal {
        skip(7 days);
         // Simulating transferInRewards() of USDe
        _earnRewards( _profitFactor);
        console2.log("Total assets on piggy after Rewards", piggy.totalAssets());

        // First Snapshot
        vm.prank(keeper);
        (uint256 totalAsset) = piggy.harvest();
        console2.log("Total assets on piggy after first harvest", totalAsset);

         // Earn Interest
        skip(8 days);
        _earnRewards(_profitFactor);
        
        vm.prank(keeper);
        (uint256 totalAsset1) = piggy.harvest();
        console2.log("Total assets on piggy after second harvest", totalAsset1);
    }

    function _liquidity(uint256 _amount) internal {
         // Liquidity
        uint256 liquidity = _amount * 20 / 100;
        console.log("Liquidity", liquidity);
        vm.prank(management);
        deal(address(asset), management, liquidity);

        vm.prank(management);
        asset.approve(address(piggy), liquidity);

        vm.prank(management);
        piggy.deposit(liquidity, management);
    }

    function test_withdrawn(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount of USDe user wants to deposit", _amount);

        _liquidity(_amount);
        
        // Deposit USDe into Piggy
        uint256 balanceBefore = asset.balanceOf(user);
        deal(address(asset), user, balanceBefore + _amount);

        vm.prank(user);
        asset.approve(address(piggy), _amount);

        vm.prank(user);
        uint256 shares = piggy.deposit(_amount, user);
        console2.log("Balance of user asset after deposit", asset.balanceOf(user));
       

        console2.log("Shares of user", shares);
        console2.log("Balance of user piggy after deposit", piggy.balanceOf(user));
        console2.log("Total assets on piggy after deposit", piggy.totalAssets());
        //assertEq(_amount,piggy.totalAssets(),"!total asset");

        _harvest(_profitFactor);

        //User wants to Cooldown
        vm.prank(user);
        piggy.cooldownShares(shares);

        // Cool Down Period
        skip(7 days);
        vm.prank(user);
        piggy.unstake(user);
        console2.log("Total assets on piggy after user unstake", piggy.totalAssets());
        assertGt(asset.balanceOf(user),_amount);
    }

    function test_rebalance(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
         _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        console2.log("Total amount of USDe user wants to deposit", _amount);

        _liquidity(_amount);
        
        // Deposit USDe into Piggy
        uint256 balanceBefore = asset.balanceOf(user);
        deal(address(asset), user, balanceBefore + _amount);

        vm.prank(user);
        asset.approve(address(piggy), _amount);

        vm.prank(user);
        piggy.deposit(_amount, user);
        console2.log("Total ERC20 on piggy after deposit of user", ERC20(erc20).balanceOf(address(piggy)));
        
        deal(address(erc20), address(piggy), _amount);
        console2.log("Total ERC20 on piggy after airdrop", ERC20(erc20).balanceOf(address(piggy)));
        
        // Cool Down Period
        skip(7 days);
        vm.prank(keeper);
        piggy.rebalance();
        uint256 totalERC20 = ERC20(erc20).balanceOf(address(piggy));
        uint256 totalAsset = piggy.totalAssets();
        uint256 percentage = 20;
        uint256 maxClaimable = (totalAsset * percentage) / 100;
        assertLt(totalERC20, maxClaimable);
        console2.log("Total ERC20 on piggy after rebalance", ERC20(erc20).balanceOf(address(piggy)));
        
    }

    function test_deposit(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
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


    function test_cooldown(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
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

    function test_unstake(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        console2.log("Total amount", _amount);

        // Deposit USDe into Piggy
        uint256 balanceBefore = asset.balanceOf(user);
        deal(address(asset), user, balanceBefore + _amount);
        deal(address(asset), user2, balanceBefore + _amount);

        vm.prank(user);
        asset.approve(address(piggy), _amount);

        

        vm.prank(user);
        uint256 pUSDeAmount = piggy.deposit(_amount, user);
        vm.prank(user);
        piggy.cooldownShares(pUSDeAmount);

        console2.log("Balance of user asset", asset.balanceOf(user));
        console2.log("Balance of user piggy", piggy.balanceOf(user));
        console2.log("Total assets on piggy", piggy.totalAssets());

         vm.prank(user2);
        asset.approve(address(piggy), _amount);

        vm.prank(user2);
        piggy.deposit(_amount, user2);
        
        console2.log("Balance of user 2 asset", asset.balanceOf(user2));
        console2.log("Balance of user 2 piggy", piggy.balanceOf(user2));
        console2.log("Total assets on piggy", piggy.totalAssets());

        skip(7 days);
        vm.prank(user);
        piggy.unstake(user);
    }

    /*function test_swap(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        deal(address(asset), address(piggy), _amount);
        
        vm.prank(keeper);
        (uint256 totalAsset1) = piggy.swap(address(asset),base);
        console2.log("Total assets 1 swapped", totalAsset1);

        vm.prank(keeper);
        (uint256 totalAsset2) = piggy.swap(base, erc20);
        console2.log("Total assets 2 swapped", totalAsset2);
    }*/

}
