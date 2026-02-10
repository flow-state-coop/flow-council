// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { FlowCouncil } from "./FlowCouncil.sol";
import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract FlowCouncilFactory {
    event FlowCouncilCreated(
        address flowCouncil, address distributionPool, string metadata
    );

    function createFlowCouncil(
        string calldata metadata,
        ISuperToken superToken
    ) public returns (FlowCouncil flowCouncil) {
        flowCouncil = new FlowCouncil(superToken, msg.sender);

        emit FlowCouncilCreated(
            address(flowCouncil),
            address(flowCouncil.distributionPool()),
            metadata
        );
    }
}
