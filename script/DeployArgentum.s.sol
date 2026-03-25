// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Argentum.sol";

contract DeployArgentum is Script {
    function run() external {
        vm.startBroadcast();
        Argentum argt = new Argentum();
        console.log("ARGENTUM (ARGT) deployed at:", address(argt));
        vm.stopBroadcast();
    }
}
