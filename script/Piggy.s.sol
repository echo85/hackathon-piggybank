// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Piggy} from "../src/Piggy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyScript is Script {
    Piggy public piggy;
    
    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address management = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey); 
        piggy = new Piggy(management);

        console.log("contract deployed", address(piggy));
        vm.stopBroadcast();

        
    }
}
