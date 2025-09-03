// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { SuperTokenV1Library } from
    "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {
    ISuperfluid,
    ISuperfluidPool
} from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ISuperToken } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { SuperfluidPool } from
    "@superfluid-finance/ethereum-contracts/contracts/agreements/gdav1/SuperfluidPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FlowCouncilFactory } from "../../src/FlowCouncilFactory.sol";
import { FlowCouncil } from "../../src/FlowCouncil.sol";
import { IFlowCouncil } from "../../src/interfaces/IFlowCouncil.sol";

contract FlowCouncilTest is Test {
    using SuperTokenV1Library for ISuperToken;

    ISuperToken superToken;
    FlowCouncilFactory flowCouncilFactory;
    FlowCouncil flowCouncil;
    address firstVoter = makeAddr("firstVoter");
    address secondVoter = makeAddr("secondVoter");
    address firstRecipient = makeAddr("firstRecipient");
    address secondRecipient = makeAddr("secondRecipient");
    address voterManager = makeAddr("voterManager");
    address granteeManager = makeAddr("granteeManager");
    address nonManager = makeAddr("nonManager");
    address superFakeDaiWhale = 0x1a8b3554089d97Ad8656eb91F34225bf97055C68;
    ISuperToken superFakeDai =
        ISuperToken(0xD6FAF98BeFA647403cc56bDB598690660D5257d2);
    IERC20 fakeDai = IERC20(0x4247bA6C3658Fa5C0F523BAcea8D0b97aF1a175e);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 28605487, urlOrAlias: "opsepolia" });

        superToken = superFakeDai;
        flowCouncilFactory = new FlowCouncilFactory();
        flowCouncil =
            flowCouncilFactory.createFlowCouncil("Flow Council", superFakeDai);

        vm.startPrank(superFakeDaiWhale);

        superFakeDai.transfer(address(this), 1 * 1e18);
        superFakeDai.transfer(address(flowCouncil), 1 * 1e18);
        fakeDai.transfer(address(this), 1 * 1e18);

        vm.stopPrank();
    }

    function test_deployment() public view {
        ISuperfluidPool distributionPool = flowCouncil.distributionPool();

        assertTrue(address(distributionPool) != address(0));
    }

    function test_updateManagers() public {
        IFlowCouncil.Manager[] memory managers = new IFlowCouncil.Manager[](2);

        managers[0] = IFlowCouncil.Manager(
            voterManager,
            flowCouncil.VOTER_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );
        managers[1] = IFlowCouncil.Manager(
            granteeManager,
            flowCouncil.RECIPIENT_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );

        flowCouncil.updateManagers(managers);

        assertTrue(
            flowCouncil.hasRole(flowCouncil.VOTER_MANAGER_ROLE(), voterManager)
        );
        assertTrue(
            flowCouncil.hasRole(
                flowCouncil.RECIPIENT_MANAGER_ROLE(), granteeManager
            )
        );

        managers[0].status = IFlowCouncil.Status.Removed;
        managers[1].status = IFlowCouncil.Status.Removed;

        flowCouncil.updateManagers(managers);

        assertFalse(
            flowCouncil.hasRole(flowCouncil.VOTER_MANAGER_ROLE(), voterManager)
        );
        assertFalse(
            flowCouncil.hasRole(
                flowCouncil.RECIPIENT_MANAGER_ROLE(), granteeManager
            )
        );
    }

    function test_updateManagers_UNAUTHORIZED() public {
        IFlowCouncil.Manager[] memory managers = new IFlowCouncil.Manager[](2);

        managers[0] = IFlowCouncil.Manager(
            voterManager,
            flowCouncil.VOTER_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );
        managers[1] = IFlowCouncil.Manager(
            granteeManager,
            flowCouncil.RECIPIENT_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.updateManagers(managers);
    }

    function test_addRecipient() public {
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Recipient memory grantee =
            flowCouncil.getRecipient(firstRecipient);

        assertEq(grantee.account, firstRecipient);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowCouncil.ALREADY_ADDED.selector, firstRecipient
            )
        );
        flowCouncil.addRecipient(firstRecipient);
    }

    function test_addRecipient_UNAUTHORIZED() public {
        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.addRecipient(firstRecipient);
    }

    function test_removeRecipient() public {
        flowCouncil.addRecipient(firstRecipient);
        vm.startSnapshotGas("S");
        flowCouncil.removeRecipient(firstRecipient);
        uint256 gasUsed = vm.stopSnapshotGas();
        console.log(gasUsed);
    }

    function test_removeRecipient_UNAUTHORIZED() public {
        flowCouncil.addRecipient(firstRecipient);
        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.removeRecipient(firstRecipient);
    }

    function test_updateRecipients() public {
        IFlowCouncil.UpdatingAccount[] memory recipients =
            new IFlowCouncil.UpdatingAccount[](2);

        recipients[0] = IFlowCouncil.UpdatingAccount(
            firstRecipient, IFlowCouncil.Status.Added
        );
        recipients[1] = IFlowCouncil.UpdatingAccount(
            secondRecipient, IFlowCouncil.Status.Added
        );

        flowCouncil.updateRecipients(recipients);

        assertEq(
            flowCouncil.getRecipient(firstRecipient).account, firstRecipient
        );
        assertEq(
            flowCouncil.getRecipient(secondRecipient).account, secondRecipient
        );

        recipients[0].status = IFlowCouncil.Status.Removed;
        recipients[1].status = IFlowCouncil.Status.Removed;

        flowCouncil.updateRecipients(recipients);

        assertEq(flowCouncil.getRecipient(firstRecipient).account, address(0));
        assertEq(flowCouncil.getRecipient(secondRecipient).account, address(0));
    }

    function test_updateRecipients_UNAUTHORIZED() public {
        IFlowCouncil.UpdatingAccount[] memory recipients =
            new IFlowCouncil.UpdatingAccount[](2);

        recipients[0] = IFlowCouncil.UpdatingAccount(
            firstRecipient, IFlowCouncil.Status.Added
        );
        recipients[1] = IFlowCouncil.UpdatingAccount(
            secondRecipient, IFlowCouncil.Status.Added
        );

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.updateRecipients(recipients);
    }

    function test_addVoter() public {
        flowCouncil.addVoter(address(this), 10);

        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(address(this));

        assertEq(voter.account, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowCouncil.ALREADY_ADDED.selector, address(this)
            )
        );
        flowCouncil.addVoter(address(this), 10);
    }

    function test_addVoter_UNAUTHORIZED() public {
        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.addVoter(address(this), 10);
    }

    function test_removeVoter() public {
        flowCouncil.addVoter(address(this), 10);
        flowCouncil.removeVoter(address(this));
        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(address(this));

        assertEq(voter.account, address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowCouncil.NOT_FOUND.selector, address(this)
            )
        );
        flowCouncil.removeVoter(address(this));
    }

    function test_editVoter() public {
        flowCouncil.addVoter(address(this), 10);
        flowCouncil.editVoter(address(this), 2);
        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(address(this));

        assertEq(voter.votingPower, 2);
    }

    function test_removeVoter_UNAUTHORIZED() public {
        flowCouncil.addVoter(address(this), 10);

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.removeVoter(address(this));
    }

    function test_updateVoters() public {
        IFlowCouncil.Voter[] memory voters = new IFlowCouncil.Voter[](2);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](0);
        voters[0] = IFlowCouncil.Voter(firstVoter, 10, votes);
        voters[1] = IFlowCouncil.Voter(secondVoter, 10, votes);

        flowCouncil.updateVoters(voters, 0);

        assertEq(flowCouncil.getVoter(firstVoter).account, firstVoter);
        assertEq(flowCouncil.getVoter(secondVoter).account, secondVoter);

        voters[0].votingPower = 0;
        voters[1].votingPower = 2;

        flowCouncil.updateVoters(voters, 0);

        assertEq(flowCouncil.getVoter(firstVoter).account, address(0));
        assertEq(flowCouncil.getVoter(secondVoter).votingPower, 2);
    }

    function test_updateVoters_UNAUTHORIZED() public {
        IFlowCouncil.Voter[] memory voters = new IFlowCouncil.Voter[](2);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](0);
        voters[0] = IFlowCouncil.Voter(firstVoter, 10, votes);
        voters[1] = IFlowCouncil.Voter(secondVoter, 10, votes);

        flowCouncil.updateVoters(voters, 0);

        voters[0].votingPower = 0;
        voters[1].votingPower = 2;

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.updateVoters(voters, 0);
    }
}
