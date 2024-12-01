# Piggy Bank

### PiggyBank is a blazing fast, yield-bearing smart contract based on the ERC-4626 standard
I created a yield-bearing smart contract based on the ERC-4626 standard. The contract accept USDe as input, staking it to earn a current APY on sUSDe. Every 7 days, the accrued yield would be used to purchase ERC-20 tokens, such as popular meme coins, with the potential profits or losses distributed back to the vault. Upon redemption, users would receive their initial USDe plus any speculative returns. <br>

**Project Miro IDEA**
https://miro.com/app/board/uXjVLFMUypU=/

**DEMO APP**
<br>
https://vercel.com/carlo-falchis-projects/hackathon-piggybank-frontend<br>

**FRONTEND GITHUB**
<br>
https://github.com/echo85/hackathon-piggybank-frontend<br>

**THE VIRTUAL TNEST (fork of Mainnet)**
<br>
> [!NOTE]
> How to setup metamask or your wallet to connect on tenderly vtnest:<br>
chain-id: 73571<br>
name: 'Virtual Ethereum Mainnet'<br>
nativeCurrency: vEther<br>
vETH<br>
decimals: 18<br>
rpcUrls: 'https://virtual.mainnet.rpc.tenderly.co/0321deab-5f87-44ec-82d3-d58bf8876874'<br>
block explorer: https://dashboard.tenderly.co/explorer/vnet/64aff5e0-624b-4af0-b055-a6fedeb2dd83/transactions<br>

**VirtualTNest  Smart Contract**
<br>
```WETH TOKEN - 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 (used as ERC20 example on Mainnet)
PIGGY Bank ERC4626 - 0x349D6F9f6b81630695eCb317062416fae508f13D 
Piggy Bankg OFT Adapter - 0x7f4DD85e7f6ACbf81687cfc4AEDC5EFcC43eCb55
```

**SEPOLIA Smart Contract**
```
PIGGY TOKEN: 0x6296665981B7bf5E39B8b7a1021692289212825A (used as ERC20 example on Sepolia)
PIGGY Bank ERC4626 - 0x9A41EfcE7b872576fd6B16490b6C3Fe6eB4973Bc 
Piggy Bankg OFT Adapter - 0xb98d9c8B1E5C05065517ED0Bb496B1c61Ee18d1C
```

**Ble Smart Contract**
```
Piggy Bankg OFT - 0xE2fC214c6A7E7BFD7DdD2Aa4043E2660dFD75dBB
```
