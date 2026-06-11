// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { FlowCouncilFactory } from "../src/FlowCouncilFactory.sol";
import { FlowCouncil } from "../src/FlowCouncil.sol";
import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract CreateFlowCouncil is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FlowCouncilFactory flowCouncilFactory =
            FlowCouncilFactory(0x589232342bfeCb372dbbc01d17e8D112a27fF125);

        FlowCouncil flowCouncil = flowCouncilFactory.createFlowCouncil(
            "E2E Live Smoke Council",
            ISuperToken(vm.envAddress("SUPER_TOKEN"))
        );

        console.log(address(flowCouncil));

        vm.stopBroadcast();
    }
}
