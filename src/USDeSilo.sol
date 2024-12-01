// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable var-name-mixedcase  */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IUSDeSiloDefinitions {
  /// @notice Error emitted when the staking vault is not the caller
  error OnlyStakingVault();
}

/**
 * @title USDeSilo
 * @notice The Silo allows to store USDe during the stake cooldown process.
 */
contract USDeSilo is IUSDeSiloDefinitions {
  address immutable _STAKING_VAULT;
  IERC20 immutable _USDE;

  constructor(address stakingVault, address usde) {
    _STAKING_VAULT = stakingVault;
    _USDE = IERC20(usde);
  }

  modifier onlyStakingVault() {
    if (msg.sender != _STAKING_VAULT) revert OnlyStakingVault();
    _;
  }

  function withdraw(address to, uint256 amount) external onlyStakingVault {
    _USDE.transfer(to, amount);
  }
}