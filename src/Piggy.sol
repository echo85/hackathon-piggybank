// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UniswapV3Swapper} from "src/UniswapV3Swapper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IStakedUSDe} from "src/interfaces/USDe/IStakedUSDe.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

import {console} from "forge-std/console.sol";

struct UserCooldown {
  uint104 cooldownEnd;
  uint152 underlyingAmount;
}

contract Piggy is ERC4626, UniswapV3Swapper, Ownable, ERC20Permit {
    using SafeERC20 for IERC20;
    address erc20;
    uint104 public cooldownTimeEnd;
    uint256 public lastSnapshotValue;
    uint256 private claimableShare;
    uint24 public cooldownDuration;
    uint256 public performanceFee = 100;
    uint256 public percentageERC20 = 20;
    bytes32 public priceFeedIdERC20 = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // WETH/USD     
    bytes32 public priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d; // USDe/USD

    mapping(address => UserCooldown) public cooldowns;
    /// @notice Error emitted when cooldown value is invalid
     error InvalidCooldown();
     /// @notice Error emitted when the shares amount to redeem is greater than the shares balance of the owner
    error ExcessiveRedeemAmount();
    /// @notice Error emitted when the shares amount to withdraw is greater than the shares balance of the owner
    error ExcessiveWithdrawAmount();

    IStakedUSDe public immutable vault;
    address _keeper;
    IPyth pyth;
    
    constructor(IERC20 asset_, address _owner, address keeper, address _vault, address _erc20, address pythContract)
    ERC20("Piggy Bank", "pUSDe")
    ERC4626(asset_)
    ERC20Permit("pUSDe")
    Ownable(_owner) {

        require(IStakedUSDe(_vault).asset() == address(asset_), "wrong vault");
        vault = IStakedUSDe(_vault);
        erc20 = _erc20;
        ERC20(asset()).approve(_vault, type(uint256).max);
        _keeper = keeper;
        pyth = IPyth(pythContract);
    }

    function updateERC20(address _erc20, bytes32 _priceFeedId) external onlyOwner {
         erc20 = _erc20;
         priceFeedIdERC20 = _priceFeedId;
    }

    function updateKeeper(address keeper) external onlyOwner {
         _keeper = keeper;
    }

    function updateFee(uint256 _performanceFee) external onlyOwner {
         performanceFee = _performanceFee;
    }

   function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        
        super._deposit(caller, receiver, assets, shares); //Deposit User USDe to SC
        vault.deposit(assets,address(this)); //Staking USDe to Staking USD
        lastSnapshotValue = lastSnapshotValue + assets;
    }

    function cooldownShares(uint256 shares) external returns (uint256 assets) {
        if (shares > maxRedeem(msg.sender)) revert ExcessiveRedeemAmount();

        assets = _convertToAssets(shares, Math.Rounding.Floor);

        cooldowns[msg.sender].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
        cooldowns[msg.sender].underlyingAmount += uint152(assets);
        uint256 usdeAvailable = _valueOfAsset();
        console.log("Cooldown request for %s, sUSDe value on piggy: %s Total assets %s", assets, _valueOfVault(),  totalAssets());
        
        uint256 value = (_valueOfErc20() * 100) / totalAssets();
        console.log("Value Percentage", value);
        
        if (usdeAvailable < assets) {
                uint256 deficit = assets - usdeAvailable;
                require(_valueOfVault() >= deficit, "Insufficient Liquidity");

                vault.cooldownAssets(deficit);
        }
        
    }
    function cooldownAssets(uint256 assets) public returns (uint256 shares) {
        if (assets > maxWithdraw(msg.sender)) revert ExcessiveWithdrawAmount();

        shares = _convertToShares(assets, Math.Rounding.Floor);
        uint256 usdeAvailable = _valueOfAsset();
        
        if (usdeAvailable < assets) {
                uint256 deficit = assets - usdeAvailable;
                require(_valueOfVault() >= deficit, "Insufficient Liquidity");

                vault.cooldownAssets(deficit);
        }
    }

    function unstake(address _receiver) public {

        vault.unstake(address(this));
        UserCooldown storage userCooldown = cooldowns[msg.sender];
        uint256 assets = userCooldown.underlyingAmount;
        console.log("Asset the user wants to unstake", assets);
        if (block.timestamp >= userCooldown.cooldownEnd || cooldownDuration == 0) {
            userCooldown.cooldownEnd = 0;
            userCooldown.underlyingAmount = 0;

            uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
            console.log("Asset avaiable", _valueOfAsset());
            console.log("Shares of the unstake user", shares);
            console.log("Balance of the user piggy", balanceOf(msg.sender));

            // Verifica quanto USDe è già disponibile nel vault
            require(_valueOfAsset() >= assets, "Insufficient USDe after swaps");
            if(shares > balanceOf(msg.sender)) shares = balanceOf(msg.sender);
            _withdraw(msg.sender, _receiver, msg.sender, assets, shares);
         } else {
            revert InvalidCooldown();
        }
    }
    
    modifier onlyKeeper {
        require(msg.sender == _keeper);
        _;
    }

     function setUniFees (
        address _token0,
        address _token1,
        uint24 _fee
    ) external onlyOwner{
        _setUniFees(_token0, _token1, _fee);
    }

    function setBase(address _base) external onlyOwner {
       base = _base;
    }

    function harvest() public
        onlyKeeper
        returns (uint256 _totalAssets)
    {
        if(claimableShare > 0 && block.timestamp > cooldownTimeEnd) {
                console.log("Claimable Shares",claimableShare);
                vault.unstake(address(this));
                uint256 assetsToSwap = vault.convertToAssets(claimableShare);
                uint256 balanceAsset = ERC20(asset()).balanceOf(address(this));
                if(assetsToSwap > balanceAsset) assetsToSwap = balanceAsset;
                console.log("Asset to swap", assetsToSwap);
                _swap(address(asset()), erc20, assetsToSwap);
                claimableShare = 0;
                lastSnapshotValue = _valueOfVault();
            }
            else if (vault.balanceOf(address(this)) > 0) {
                console.logString("No claimable, then cooldown");
                console.log("Snapshot value", lastSnapshotValue);
                uint256 previewReedem = vault.previewRedeem(vault.balanceOf(address(this)));
                if(previewReedem > lastSnapshotValue) {
                    uint256 assetToClaim = vault.previewRedeem(vault.balanceOf(address(this))) - lastSnapshotValue;
                    console.log("assetToClaim ", assetToClaim);
                    uint256 valueErc20 = (_valueOfErc20() * 100) / totalAssets();
                    console.log("ERC20 NO Claimable Percentage", valueErc20);
                    if( assetToClaim > 0 && valueErc20 < percentageERC20) 
                    {
                        uint256 maxClaimable = (totalAssets() * percentageERC20) / 100;
                        assetToClaim = (assetToClaim > maxClaimable) ? maxClaimable : assetToClaim;
                        claimableShare = vault.cooldownAssets(assetToClaim);
                        cooldownTimeEnd = uint104(block.timestamp) + 7 days;
                    }
                }
               
            }        

        _totalAssets = totalAssets();
    }

    function rebalance() public
        onlyKeeper
        returns (uint256 _totalAssets)
    {
        uint256 valueErc20 = _valueOfErc20();
        uint256 maxClaimable = (totalAssets() * percentageERC20) / 100;
        uint256 toSwap = (valueErc20 > maxClaimable) ? valueErc20 - maxClaimable : 0;
        if(toSwap > 0)
            _swapERC20(erc20, address(asset()),toSwap);
         
        _totalAssets = totalAssets();
    }

    function _swap(address from, address to, uint256 amount) internal
        returns (uint256 _amountOut)
    {   
        uint256 _amountSwap = _swapFrom(from, base, amount, 0);   
        _amountOut = _swapFrom(base, to, _amountSwap, 0);
    }

    function _swapERC20(address from, address to, uint256 amount) internal
        returns (uint256 _amountOut)
    {   
       uint256 amountIn = _valueInERC20(amount);
        if(amountIn > ERC20(erc20).balanceOf(address(this))) amountIn = ERC20(erc20).balanceOf(address(this));
        _amountOut = _swapFrom(from, to, amountIn, 0);   
    }

    function totalAssets() public view override returns (uint256) {
        uint256 erc20Value = _valueOfErc20();
        uint256 fee = (erc20Value > 0) ? (erc20Value * performanceFee) / 10_000 : 0; 
        return _valueOfVault() + _valueOfAsset() + (erc20Value - fee);
    }

    function _valueOfAsset() internal view returns (uint256) {
        return ERC20(asset()).balanceOf(address(this));
    }

    function _valueOfErc20() internal view returns (uint256) {
        if(ERC20(erc20).balanceOf(address(this)) == 0) return 0;
        else { 
            PythStructs.Price memory priceUSDeToUsd = pyth.getPriceUnsafe(priceFeedIdUSDe);
            PythStructs.Price memory priceERC20toUsd = pyth.getPriceUnsafe(priceFeedIdERC20);
            
            uint256 basePriceERC20toUsd = PythUtils.convertToUint(
            priceERC20toUsd.price,
            priceERC20toUsd.expo,
            18);

            uint256 basePriceUSDeToUsd = PythUtils.convertToUint(
            priceUSDeToUsd.price,
            priceUSDeToUsd.expo,
            18);

            uint256 wethPriceInUsde = basePriceERC20toUsd / basePriceUSDeToUsd;
            return  ERC20(erc20).balanceOf(address(this)) * wethPriceInUsde;
            
        }
    }

    function _valueInERC20(uint256 _amount) internal view returns (uint256) {
        if(ERC20(erc20).balanceOf(address(this)) == 0) return 0;
        else {
            PythStructs.Price memory priceUSDeToUsd = pyth.getPriceUnsafe(priceFeedIdUSDe);
            PythStructs.Price memory priceERC20toUsd = pyth.getPriceUnsafe(priceFeedIdERC20);
            
            uint256 basePriceERC20toUsd = PythUtils.convertToUint(
            priceERC20toUsd.price,
            priceERC20toUsd.expo,
            18);

            uint256 basePriceUSDeToUsd = PythUtils.convertToUint(
            priceUSDeToUsd.price,
            priceUSDeToUsd.expo,
            18);

            uint256 wethPriceInUsde =   _amount * basePriceUSDeToUsd / basePriceERC20toUsd;
            return  wethPriceInUsde;
            
        }
    }

    function _valueOfVault() internal view returns (uint256) {
        return vault.convertToAssets(_balanceOfVault());
    }

    function _balanceOfVault() internal view returns (uint256) {
        return vault.balanceOf(address(this));
    }

    /// @dev Necessary because both ERC20 (from ERC20Permit) and ERC4626 declare decimals()
    function decimals() public pure override(ERC4626, ERC20) returns (uint8) {
        return 18;
    }
}