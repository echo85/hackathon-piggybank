// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UniswapV3Swapper} from "src/UniswapV3Swapper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IQuoter} from "@uniswap-periphery/interfaces/IQuoter.sol";

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

    uint256 public number;
    ERC20 public immutable erc20;
    uint104 public cooldownTimeEnd;
    uint256 public lastSnapshotValue;
    uint256 private claimableShare;
    uint24 public cooldownDuration;
    IQuoter public immutable quoter;

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
        erc20 = ERC20(_erc20);
        ERC20(asset()).approve(_vault, type(uint256).max);
        _keeper = keeper;
        pyth = IPyth(pythContract);
        quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    }

   function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        
        super._deposit(caller, receiver, assets, shares); //Deposit User USDe to SC
        vault.deposit(assets,address(this)); //Staking USDe to Staking USD
        lastSnapshotValue = lastSnapshotValue + assets;
    }

    function cooldownShares(uint256 shares) external returns (uint256 assets) {
        if (shares > maxRedeem(msg.sender)) revert ExcessiveRedeemAmount();

        assets = previewRedeem(shares);

        cooldowns[msg.sender].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
        cooldowns[msg.sender].underlyingAmount += uint152(assets);
        uint256 usdeAvailable = _valueOfAsset();
        console.log("Cooldown request for %s, USDe value on piggy: %s Total assets %s", assets, _valueOfAsset(), totalAssets());
        if (usdeAvailable < assets) {
                // Calcola il deficit da coprire tramite sUSDe e WETH
                uint256 deficit = assets - usdeAvailable;
                uint256 erc20total = _valueOfErc20();

                uint256 toSwap = (deficit > erc20total) ? erc20total : deficit;
                // Swap ERC20 to USDe
                uint256 swappedFromERC20 = 0;
                if(toSwap > 0)
                    swappedFromERC20 = _swapERC20(address(erc20),asset(),toSwap);
                console.log("Swapped %s", swappedFromERC20, deficit);
                 // Se ancora non basta, swap WETH in USDe
                if (swappedFromERC20 < deficit) {
                    uint256 remainingDeficit = deficit - swappedFromERC20;
                    console.log("Remain Deficit %s", remainingDeficit);
                    console.log("Remain sUSDe %s", _valueOfVault());
                    uint256 remainingDeficit1 = (remainingDeficit > _valueOfVault()) ? remainingDeficit - _valueOfVault() : remainingDeficit;
                    remainingDeficit = (remainingDeficit > _valueOfVault()) ?_valueOfVault() : remainingDeficit;
                   
                    vault.cooldownAssets(remainingDeficit);
                    
                    console.log("Remainign Deficit", remainingDeficit1);
                }  
        }
        
    }
    function cooldownAssets(uint256 assets) public returns (uint256 shares) {
        if (assets > maxWithdraw(msg.sender)) revert ExcessiveWithdrawAmount();

        shares = _convertToShares(assets, Math.Rounding.Floor);
        cooldowns[msg.sender].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
        cooldowns[msg.sender].underlyingAmount += uint152(assets);
        
        vault.cooldownAssets(assets);
    }

    function unstake(address _receiver) public {

        vault.unstake(address(this));
        UserCooldown storage userCooldown = cooldowns[msg.sender];
        uint256 assets = userCooldown.underlyingAmount;
        console.log("Asset of the unstake user", assets);
        if (block.timestamp >= userCooldown.cooldownEnd || cooldownDuration == 0) {
            userCooldown.cooldownEnd = 0;
            userCooldown.underlyingAmount = 0;

            uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
            console.log("Shares of the unstake user", shares);
            console.log("Balance of the user piggy", balanceOf(msg.sender));

            // Verifica quanto USDe è già disponibile nel vault
            require(_valueOfAsset() >= assets, "Insufficient USDe after swaps");
                
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
                _swap(asset(), address(erc20), assetsToSwap);
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
                    if( assetToClaim > 0 ) 
                    {
                        claimableShare = vault.cooldownAssets(assetToClaim);
                        cooldownTimeEnd = uint104(block.timestamp) + 7 days;
                    }
                }
               
            }        

        _totalAssets = totalAssets();
    }

    // onlyforTest
    function swap(address from, address to) public
        onlyKeeper
        returns (uint256 _amountOut)
    {
        uint256 amount = ERC20(from).balanceOf(address(this));
        _amountOut = _swapFrom(from, to, amount, 0);   
    }

    function _swap(address from, address to, uint256 amount) internal
        returns (uint256 _amountOut)
    {   
        console.log("Swapped USDe", amount);
        uint256 _amountSwap = _swapFrom(from, base, amount, 0);   
        console.log("Swapped USDe for USDt", _amountSwap);
        _amountOut = _swapFrom(base, to, _amountSwap, 0);
        console.log("Swapped USDT for WETH", _amountOut);
    }

    function _swapERC20(address from, address to, uint256 amount) internal
        returns (uint256 _amountOut)
    {   
        console.log("Wanted to Swap ERC20 asset amount", amount);
        console.log("Balance of ERC20", erc20.balanceOf(address(this)));
        
        bytes memory path = abi.encodePacked(
                    to,
                    uniFees[to][base], // base-to fee
                    base,
                    uniFees[base][from], // from-base fee
                    from
                );

        uint256 amountIn = quoter.quoteExactOutput(path, amount);
         console.log("Amount in quoter", amountIn);
        if(amountIn > erc20.balanceOf(address(this))) amountIn = erc20.balanceOf(address(this));
        _amountOut = _swapFrom(from, to, amountIn, 0);   
        console.log("Amount in swapped", amountIn);
        //_amountOut = _swapFrom(base, to, _amountSwap, 0);
        console.log("Swapped USDT for USDe", _amountOut);
    }

    function totalAssets() public view override returns (uint256) {
        console.log("Sum %s + %s + %s",_valueOfVault(),_valueOfAsset(),_valueOfErc20());
        return _valueOfVault() + _valueOfAsset() + _valueOfErc20();
        // sUSDe (assetValue) + USDe + ERC20 
    }

    function _valueOfAsset() internal view returns (uint256) {
        return ERC20(asset()).balanceOf(address(this));
    }

    function _valueOfErc20() internal view returns (uint256) {
        if(erc20.balanceOf(address(this)) == 0) return 0;
        else {
            bytes32 priceFeedIdERC20 = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // WETH/USD     
            bytes32 priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d; // USDe/USD
            
            PythStructs.Price memory priceUSDeToUsd = pyth.getPriceUnsafe(priceFeedIdUSDe);
            PythStructs.Price memory priceERC20toUsd = pyth.getPriceUnsafe(priceFeedIdERC20);
            
            uint256 basePriceERC20toUsd = PythUtils.convertToUint(
            priceERC20toUsd.price,
            priceERC20toUsd.expo,
            18);

            //console.log("ERC20 to USD %s", basePriceERC20toUsd);

            uint256 basePriceUSDeToUsd = PythUtils.convertToUint(
            priceUSDeToUsd.price,
            priceUSDeToUsd.expo,
            18);

            //console.log("USD to USDe %s", basePriceUSDeToUsd);

            //console.log("Balance of ERC20", erc20.balanceOf(address(this)));
            uint256 wethPriceInUsde = basePriceERC20toUsd / basePriceUSDeToUsd;
            return  erc20.balanceOf(address(this)) * wethPriceInUsde;
            
        }
    }

    function _valueInERC20(uint256 _amount) internal view returns (uint256) {
        if(erc20.balanceOf(address(this)) == 0) return 0;
        else {
            bytes32 priceFeedIdERC20 = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // WETH/USD     
            bytes32 priceFeedIdUSDe = 0x6ec879b1e9963de5ee97e9c8710b742d6228252a5e2ca12d4ae81d7fe5ee8c5d; // USDe/USD
            
            PythStructs.Price memory priceUSDeToUsd = pyth.getPriceUnsafe(priceFeedIdUSDe);
            PythStructs.Price memory priceERC20toUsd = pyth.getPriceUnsafe(priceFeedIdERC20);
            
            uint256 basePriceERC20toUsd = PythUtils.convertToUint(
            priceERC20toUsd.price,
            priceERC20toUsd.expo,
            18);

            console.log("ERC20 to USD %s", basePriceERC20toUsd);

            uint256 basePriceUSDeToUsd = PythUtils.convertToUint(
            priceUSDeToUsd.price,
            priceUSDeToUsd.expo,
            18);

            console.log("USD to USDe %s", basePriceUSDeToUsd);

            //console.log("Balance of ERC20", erc20.balanceOf(address(this)));
            uint256 wethPriceInUsde =   _amount * basePriceUSDeToUsd / basePriceERC20toUsd;
            console.log("USDe to USD / ERC20 to USD", wethPriceInUsde);
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
