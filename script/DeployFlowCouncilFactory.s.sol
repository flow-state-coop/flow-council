// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { FlowCouncilFactory } from "../src/FlowCouncilFactory.sol";

contract DeployFlowCouncilFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        new FlowCouncilFactory();

        vm.stopBroadcast();
    }
}
