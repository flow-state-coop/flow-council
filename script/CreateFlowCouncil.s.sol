// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { FlowCouncilFactory } from "../src/FlowCouncilFactory.sol";
import { FlowCouncil } from "../src/FlowCouncil.sol";
import { ISuperToken } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract CreateFlowCouncil is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FlowCouncilFactory flowCouncilFactory =
            FlowCouncilFactory(0x27b27a6471fF12E24bE368E184B96654b3e03454);

        FlowCouncil flowCouncil = flowCouncilFactory.createFlowCouncil(
            "Flow Council",
            ISuperToken(0x0043d7c85C8b96a49A72A92C0B48CdC4720437d7)
        );

        console.log(address(flowCouncil));

        vm.stopBroadcast();
    }
}
