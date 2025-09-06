// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { FlowCouncilFactory } from "../src/FlowCouncilFactory.sol";

contract DeployFlowCouncilFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = 0xf1e1726d79293b680310e12f13dab1e0affbe7fca3301bc2dbdc84afae902541;

        FlowCouncilFactory flowCouncilFactory = new FlowCouncilFactory{salt: salt}();

        console.log(address(flowCouncilFactory));

        vm.stopBroadcast();
    }
}
