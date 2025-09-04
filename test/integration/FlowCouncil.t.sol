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
    address recipientManager = makeAddr("recipientManager");
    address nonManager = makeAddr("nonManager");
    ISuperToken superFakeDai =
        ISuperToken(0xD6FAF98BeFA647403cc56bDB598690660D5257d2);
    IERC20 fakeDai = IERC20(0x4247bA6C3658Fa5C0F523BAcea8D0b97aF1a175e);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 28605487, urlOrAlias: "opsepolia" });

        superToken = superFakeDai;
        flowCouncilFactory = new FlowCouncilFactory();
        flowCouncil =
            flowCouncilFactory.createFlowCouncil("Flow Council", superFakeDai);
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
            recipientManager,
            flowCouncil.RECIPIENT_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );

        flowCouncil.updateManagers(managers);

        assertTrue(
            flowCouncil.hasRole(flowCouncil.VOTER_MANAGER_ROLE(), voterManager)
        );
        assertTrue(
            flowCouncil.hasRole(
                flowCouncil.RECIPIENT_MANAGER_ROLE(), recipientManager
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
                flowCouncil.RECIPIENT_MANAGER_ROLE(), recipientManager
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
            recipientManager,
            flowCouncil.RECIPIENT_MANAGER_ROLE(),
            IFlowCouncil.Status.Added
        );

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.updateManagers(managers);
    }

    function test_addRecipient() public {
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Recipient memory recipient =
            flowCouncil.getRecipient(firstRecipient);

        assertEq(
            recipient.account,
            firstRecipient,
            "Recipient should be added to Flow Council"
        );

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
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 10);

        vm.startPrank(firstVoter);
        flowCouncil.vote(votes);
        vm.stopPrank();

        assertEq(flowCouncil.getVotes(firstVoter)[0].amount, 10);
        assertEq(flowCouncil.getRecipient(firstRecipient).votes, 10);

        flowCouncil.removeRecipient(firstRecipient);

        IFlowCouncil.Recipient memory recipient =
            flowCouncil.getRecipient(firstRecipient);

        assertEq(
            recipient.account,
            address(0),
            "Recipient should be removed from Flow Council"
        );
        assertEq(
            flowCouncil.getVotes(firstVoter).length,
            0,
            "Votes should have been removed"
        );
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
            flowCouncil.getRecipient(firstRecipient).account,
            firstRecipient,
            "Recipient should be added to Flow Council"
        );
        assertEq(
            flowCouncil.getRecipient(secondRecipient).account,
            secondRecipient,
            "Recipient should be added to Flow Council"
        );

        recipients[0].status = IFlowCouncil.Status.Removed;
        recipients[1].status = IFlowCouncil.Status.Removed;

        flowCouncil.updateRecipients(recipients);

        assertEq(
            flowCouncil.getRecipient(firstRecipient).account,
            address(0),
            "Recipient should be removed from Flow Council"
        );
        assertEq(
            flowCouncil.getRecipient(secondRecipient).account,
            address(0),
            "Recipient should be removed from Flow Council"
        );
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
        flowCouncil.addVoter(firstVoter, 10);

        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(firstVoter);

        assertEq(
            voter.account, firstVoter, "Voter should be added to Flow Council"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowCouncil.ALREADY_ADDED.selector, firstVoter
            )
        );
        flowCouncil.addVoter(firstVoter, 10);
    }

    function test_addVoter_UNAUTHORIZED() public {
        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.addVoter(firstVoter, 10);
    }

    function test_removeVoter() public {
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 10);

        vm.startPrank(firstVoter);
        flowCouncil.vote(votes);
        vm.stopPrank();

        assertEq(flowCouncil.getVotes(firstVoter)[0].amount, 10);
        assertEq(flowCouncil.getRecipient(firstRecipient).votes, 10);

        flowCouncil.removeVoter(firstVoter);
        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(firstVoter);
        IFlowCouncil.Recipient memory recipient =
            flowCouncil.getRecipient(firstRecipient);

        assertEq(
            voter.account,
            address(0),
            "Voter should be removed from Flow Council"
        );
        assertEq(
            flowCouncil.getVotes(firstVoter).length,
            0,
            "Votes should have been removed"
        );
        assertEq(recipient.votes, 0, "Recipient votes should have been removed");

        vm.expectRevert(
            abi.encodeWithSelector(IFlowCouncil.NOT_FOUND.selector, firstVoter)
        );
        flowCouncil.removeVoter(firstVoter);
    }

    function test_editVoter() public {
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.editVoter(firstVoter, 2);
        IFlowCouncil.Voter memory voter = flowCouncil.getVoter(firstVoter);

        assertEq(voter.votingPower, 2, "Voting power should be updated");
    }

    function test_removeVoter_UNAUTHORIZED() public {
        flowCouncil.addVoter(firstVoter, 10);

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.removeVoter(firstVoter);
    }

    function test_updateVoters() public {
        IFlowCouncil.Voter[] memory voters = new IFlowCouncil.Voter[](2);

        IFlowCouncil.CurrentVote[] memory currentVotes =
            new IFlowCouncil.CurrentVote[](0);
        voters[0] = IFlowCouncil.Voter(firstVoter, 10, currentVotes);
        voters[1] = IFlowCouncil.Voter(secondVoter, 10, currentVotes);

        flowCouncil.updateVoters(voters, 0);

        assertEq(
            flowCouncil.getVoter(firstVoter).account,
            firstVoter,
            "Voter should be added to Flow Council"
        );
        assertEq(
            flowCouncil.getVoter(secondVoter).account,
            secondVoter,
            "Voter should be added to Flow Council"
        );

        voters[0].votingPower = 0;
        voters[1].votingPower = 2;

        flowCouncil.updateVoters(voters, 0);

        assertEq(
            flowCouncil.getVoter(firstVoter).account,
            address(0),
            "Voter should be removed from Flow Council"
        );
        assertEq(
            flowCouncil.getVoter(secondVoter).votingPower,
            2,
            "Voter should be removed from Flow Council"
        );
    }

    function test_updateVoters_UNAUTHORIZED() public {
        IFlowCouncil.Voter[] memory voters = new IFlowCouncil.Voter[](2);

        IFlowCouncil.CurrentVote[] memory currentVotes =
            new IFlowCouncil.CurrentVote[](0);
        voters[0] = IFlowCouncil.Voter(firstVoter, 10, currentVotes);
        voters[1] = IFlowCouncil.Voter(secondVoter, 10, currentVotes);

        flowCouncil.updateVoters(voters, 0);

        voters[0].votingPower = 0;
        voters[1].votingPower = 2;

        vm.prank(nonManager);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.updateVoters(voters, 0);
    }

    function test_vote_single() public {
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 10);

        vm.prank(firstVoter);
        flowCouncil.vote(votes);

        ISuperfluidPool distributionPool = flowCouncil.distributionPool();

        assertEq(
            distributionPool.getUnits(firstRecipient),
            10,
            "Recipient should have units assigned in the distribution pool"
        );
        assertEq(
            flowCouncil.getRecipient(firstRecipient).votes,
            10,
            "Recipient should have votes in storage"
        );
        assertEq(
            flowCouncil.getVoter(firstVoter).votes[0].amount,
            10,
            "Voter should have votes in storage"
        );
    }

    function test_vote_multiple() public {
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.addVoter(secondVoter, 10);
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 10);

        vm.prank(firstVoter);
        flowCouncil.vote(votes);

        ISuperfluidPool distributionPool = flowCouncil.distributionPool();

        assertEq(distributionPool.getUnits(firstRecipient), 10);
        assertEq(flowCouncil.getRecipient(firstRecipient).votes, 10);
        assertEq(flowCouncil.getVoter(firstVoter).votes[0].amount, 10);

        vm.prank(secondVoter);
        flowCouncil.vote(votes);

        assertEq(
            distributionPool.getUnits(firstRecipient),
            20,
            "Recipient should have units assigned in the distribution pool"
        );
        assertEq(
            flowCouncil.getRecipient(firstRecipient).votes,
            20,
            "Recipient should have votes in storage"
        );
        assertEq(
            flowCouncil.getVoter(secondVoter).votes[0].amount,
            10,
            "Voter should have votes in storage"
        );
    }

    function test_vote_UNAUTHORIZED() public {
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 11);

        vm.prank(firstVoter);
        vm.expectRevert(IFlowCouncil.UNAUTHORIZED.selector);
        flowCouncil.vote(votes);
    }

    function test_vote_NOT_FOUND() public {
        flowCouncil.addVoter(firstVoter, 10);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 11);

        vm.prank(firstVoter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowCouncil.NOT_FOUND.selector, firstRecipient
            )
        );
        flowCouncil.vote(votes);
    }

    function test_vote_NOT_ENOUGH_VOTING_POWER() public {
        flowCouncil.addVoter(firstVoter, 10);
        flowCouncil.addRecipient(firstRecipient);

        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](1);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 11);

        vm.prank(firstVoter);
        vm.expectRevert(IFlowCouncil.NOT_ENOUGH_VOTING_POWER.selector);
        flowCouncil.vote(votes);
    }

    function test_vote_TOO_MUCH_VOTING_SPREAD() public {
        IFlowCouncil.CurrentVote[] memory currentVotes =
            new IFlowCouncil.CurrentVote[](0);
        IFlowCouncil.Vote[] memory votes = new IFlowCouncil.Vote[](2);
        IFlowCouncil.Voter[] memory voters = new IFlowCouncil.Voter[](1);

        voters[0] = IFlowCouncil.Voter(firstVoter, 10, currentVotes);

        flowCouncil.updateVoters(voters, 1);
        flowCouncil.addRecipient(firstRecipient);
        flowCouncil.addRecipient(secondRecipient);

        votes[0] = IFlowCouncil.Vote(firstRecipient, 5);
        votes[1] = IFlowCouncil.Vote(secondRecipient, 5);

        vm.prank(firstVoter);
        vm.expectRevert(IFlowCouncil.TOO_MUCH_VOTING_SPREAD.selector);
        flowCouncil.vote(votes);
    }

    function test_vote_update() public {
        flowCouncil.addVoter(firstVoter, 55);

        IFlowCouncil.UpdatingAccount[] memory recipients =
            new IFlowCouncil.UpdatingAccount[](6);

        for (uint160 i = 0; i < recipients.length; i++) {
            recipients[i] = IFlowCouncil.UpdatingAccount(
                address(i + 1), IFlowCouncil.Status.Added
            );
        }

        flowCouncil.updateRecipients(recipients);

        IFlowCouncil.Vote[] memory votes =
            new IFlowCouncil.Vote[](recipients.length);
        ISuperfluidPool distributionPool = flowCouncil.distributionPool();

        uint96 totalVotes;

        for (uint96 i = 0; i < votes.length; i++) {
            votes[i] = IFlowCouncil.Vote(recipients[i].account, i + 1);
            totalVotes = totalVotes + i + 1;
        }

        vm.startPrank(firstVoter);
        flowCouncil.vote(votes);

        for (uint256 i = 0; i < votes.length; i++) {
            assertEq(
                distributionPool.getUnits(votes[i].recipient),
                votes[i].amount,
                "Recipient should have units assigned in the distribution pool"
            );
            assertEq(
                flowCouncil.getRecipient(votes[i].recipient).votes,
                votes[i].amount,
                "Recipient should have votes in storage"
            );
            assertEq(
                flowCouncil.getVoter(firstVoter).votes[i].amount,
                votes[i].amount,
                "Voter should have votes in storage"
            );
        }

        for (uint160 i = 0; i < votes.length; i++) {
            votes[i].amount -= 1;
        }

        flowCouncil.vote(votes);

        for (uint256 i = 0; i < votes.length; i++) {
            assertEq(
                distributionPool.getUnits(votes[i].recipient),
                votes[i].amount,
                "Recipient should have units assigned in the distribution pool"
            );
            assertEq(
                flowCouncil.getRecipient(votes[i].recipient).votes,
                votes[i].amount,
                "Recipient should have votes in storage"
            );
            assertEq(
                flowCouncil.getVoter(firstVoter).votes[i].amount,
                votes[i].amount,
                "Voter should have votes in storage"
            );
        }
    }
}
