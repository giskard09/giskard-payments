// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiskardPayments.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        GiskardPayments gp = new GiskardPayments();
        console.log("GiskardPayments deployed at:", address(gp));
        vm.stopBroadcast();
    }
}
