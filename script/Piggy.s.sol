// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Piggy} from "../src/Piggy.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";


contract PiggyScript is Script {
    Piggy public piggy;

    function setUp() public {}

    function run() public {

        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //address deployerAddr = vm.addr(deployerPrivateKey);
        address keeper = 0x7617C64A8C4DAf8D80fe4d6825E5a3048Fb4b20b; //TBD Gelato Network?
        address management = 0x7617C64A8C4DAf8D80fe4d6825E5a3048Fb4b20b;
        //IERC20 usde = IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3); // MAINNET
        IERC20 usde = IERC20(0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696); // SEPOLIA
        
        vm.startBroadcast();
        
        address vault = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDE MAINNET
        address erc20 = 0x6982508145454Ce325dDbE47a25d4ec3d2311933; // PEPE MAINNET
        address pythAddress = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
        //IERC20 usde = IERC20(0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696); // SEPOLIA
        piggy = new Piggy(usde, management, keeper, vault, erc20, pythAddress);

        vm.stopBroadcast();
    }
}
