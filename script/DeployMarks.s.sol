// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiskardMarks.sol";

contract DeployMarks is Script {
    function run() external {
        vm.startBroadcast();
        GiskardMarks marks = new GiskardMarks();
        console.log("GiskardMarks deployed at:", address(marks));
        vm.stopBroadcast();
    }
}
