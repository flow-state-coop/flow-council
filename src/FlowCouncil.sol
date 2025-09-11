// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import {
    ISuperToken,
    ISuperfluidPool
} from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ISuperToken } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { PoolConfig } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import { SuperTokenV1Library } from
    "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { IFlowCouncil } from "./interfaces/IFlowCouncil.sol";

contract FlowCouncil is IFlowCouncil, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    /**
     * @notice The recipients counter, used for recipient ids
     * @dev It increase every time a recipient is added, so if a recipient
     * is removed and added back will have a different id and can be used
     * to validate old votes that shouldn't be relevant anymore
     */
    uint160 private recipientCount;

    /**
     * @notice The super token to distribute
     */
    ISuperToken public superToken;

    /**
     * @notice The distribution pool which streams super tokens to recipients
     */
    ISuperfluidPool public distributionPool;

    /**
     * @notice The maximum amount of recipients that a voter can vote for
     * @dev A zero value means it is uncapped
     */
    uint8 public maxVotingSpread;

    /**
     * @notice Maps the recipient address to a Recipient
     */
    mapping(address => Recipient) public recipients;

    /**
     * @notice Maps the recipient id to a Recipient
     */
    mapping(uint160 => Recipient) public recipientById;

    /**
     * @notice Maps the recipient address to an id
     */
    mapping(address => uint160) public recipientIdByAddress;

    /**
     * @notice Maps the voter address to a Voter
     */
    mapping(address => Voter) public voters;

    /**
     * @notice The recipients manager role hash
     */
    bytes32 public constant RECIPIENT_MANAGER_ROLE =
        keccak256("RECIPIENT_MANAGER_ROLE");

    /**
     * @notice The voters manager role hash
     */
    bytes32 public constant VOTER_MANAGER_ROLE = keccak256("VOTER_MANAGER_ROLE");

    /**
     * @notice Checks if the caller is not the admin
     */
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UNAUTHORIZED();
        }
        _;
    }

    /**
     * @notice Checks if the caller is not a voter manager
     */
    modifier onlyVoterManager() {
        if (!hasRole(VOTER_MANAGER_ROLE, msg.sender)) {
            revert UNAUTHORIZED();
        }
        _;
    }

    /**
     * @notice Checks if the caller is not a recipient manager
     */
    modifier onlyRecipientManager() {
        if (!hasRole(RECIPIENT_MANAGER_ROLE, msg.sender)) {
            revert UNAUTHORIZED();
        }
        _;
    }

    /**
     * @notice Creates a distribution pool and grants roles to the initial admin
     * @param _superToken The super token to distribute
     * @param _admin The initial admin address
     */
    constructor(ISuperToken _superToken, address _admin) {
        superToken = _superToken;
        distributionPool = SuperTokenV1Library.createPool(
            superToken, address(this), PoolConfig(false, true)
        );

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VOTER_MANAGER_ROLE, _admin);
        _grantRole(RECIPIENT_MANAGER_ROLE, _admin);
    }

    /**
     * @dev Set the maximum voting spread
     * @param _maxVotingSpread New maximum voting spread
     */
    function setMaxVotingSpread(uint8 _maxVotingSpread)
        public
        onlyVoterManager
    {
        maxVotingSpread = _maxVotingSpread;

        emit MaxVotingSpreadSet(_maxVotingSpread);
    }

    /**
     * @notice Update the flow council managers
     * @param _managers The address, role and status of the managers
     */
    function updateManagers(Manager[] memory _managers) external onlyAdmin {
        for (uint256 i = 0; i < _managers.length; i++) {
            if (_managers[i].status == Status.Added) {
                _grantRole(_managers[i].role, _managers[i].account);
            } else if (_managers[i].status == Status.Removed) {
                _revokeRole(_managers[i].role, _managers[i].account);
            }
        }
    }

    /**
     * @notice Adds a new recipient
     * @param _account The recipient address
     */
    function addRecipient(address _account, string calldata _metadata)
        public
        onlyRecipientManager
    {
        Recipient storage recipient = recipients[_account];

        if (recipient.account != address(0)) {
            revert ALREADY_ADDED(_account);
        }

        recipientCount++;
        recipient.account = _account;
        recipientById[recipientCount] = recipient;
        recipientIdByAddress[recipient.account] = recipientCount;

        emit RecipientAdded(_account, _metadata);
    }

    /**
     * @notice Removes a recipient
     * @param _account The recipient address
     */
    function removeRecipient(address _account) public onlyRecipientManager {
        if (recipients[_account].account == address(0)) {
            revert NOT_FOUND(_account);
        }

        delete recipients[_account];
        delete recipientById[recipientIdByAddress[_account]];
        delete recipientIdByAddress[_account];

        distributionPool.updateMemberUnits(_account, 0);

        emit RecipientRemoved(_account);
    }

    /**
     * @notice Updates the flow council recipients
     * @param _recipients The recipients to add or remove
     */
    function updateRecipients(
        UpdatingAccount[] calldata _recipients,
        string[] calldata _metadata
    ) external onlyRecipientManager {
        if (_recipients.length != _metadata.length) {
            revert INVALID();
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_recipients[i].status == Status.Removed) {
                removeRecipient(_recipients[i].account);
            } else {
                addRecipient(_recipients[i].account, _metadata[i]);
            }
        }
    }

    /**
     * @notice Adds a new voter
     * @param _account The voter address
     * @param _votingPower The voting power to assign
     */
    function addVoter(address _account, uint96 _votingPower)
        public
        onlyVoterManager
    {
        Voter storage voter = voters[_account];

        if (voter.account != address(0)) {
            revert ALREADY_ADDED(_account);
        }

        if (_votingPower == 0) {
            revert INVALID();
        }

        voter.account = _account;
        voter.votingPower = _votingPower;

        emit VoterAdded(_account, _votingPower);
    }

    /**
     * @notice Removes a voter
     * @param _account The voter address
     */
    function removeVoter(address _account) public onlyVoterManager {
        if (voters[_account].account == address(0)) {
            revert NOT_FOUND(_account);
        }

        Voter memory voter = voters[_account];

        for (uint256 i = 0; i < voter.votes.length; i++) {
            Recipient storage recipient =
                recipientById[voter.votes[i].recipientId];

            if (recipient.account != address(0)) {
                uint96 recipientVotesNew =
                    recipient.votes - voter.votes[i].amount;
                distributionPool.updateMemberUnits(
                    recipient.account, recipientVotesNew
                );
                recipient.votes = recipientVotesNew;
                recipients[recipient.account] = recipient;
            }
        }

        delete voters[_account];

        emit VoterRemoved(_account);
    }

    /**
     * @notice Edit a voter
     * @param _account The voter address
     * @param _votingPower The new voting power
     */
    function editVoter(address _account, uint96 _votingPower)
        public
        onlyVoterManager
    {
        if (voters[_account].account == address(0)) {
            revert NOT_FOUND(_account);
        }

        if (_votingPower == 0) {
            revert INVALID();
        }

        voters[_account].votingPower = _votingPower;

        emit VoterEdited(_account, _votingPower);
    }

    /**
     * @notice Updates the voters and max voting spread
     * @param _voters The voters to update
     * @param _maxVotingSpread The new max voting spread
     */
    function updateVoters(Voter[] memory _voters, uint8 _maxVotingSpread)
        external
        onlyVoterManager
    {
        for (uint256 i = 0; i < _voters.length; i++) {
            if (_voters[i].votingPower == 0) {
                removeVoter(_voters[i].account);
            } else if (voters[_voters[i].account].votingPower > 0) {
                editVoter(_voters[i].account, _voters[i].votingPower);
            } else {
                addVoter(_voters[i].account, _voters[i].votingPower);
            }
        }

        if (_maxVotingSpread != maxVotingSpread) {
            maxVotingSpread = _maxVotingSpread;

            emit MaxVotingSpreadSet(_maxVotingSpread);
        }
    }

    /**
     * @notice Updates the weights of the distribution pool based on the votes
     * to the recipients
     * @param _votes An array of votes with the recipient and vote amount
     */
    function vote(Vote[] calldata _votes) external {
        Voter storage voter = voters[msg.sender];

        if (voter.account == address(0)) {
            revert UNAUTHORIZED();
        }

        for (uint256 i = 0; i < _votes.length; i++) {
            Recipient storage recipient = recipients[_votes[i].recipient];
            uint160 recipientId = recipientIdByAddress[_votes[i].recipient];

            if (recipient.account == address(0)) {
                revert NOT_FOUND(_votes[i].recipient);
            }

            bool hasAlreadyVoted = false;
            uint96 recipientVotesCurrent = recipient.votes;

            for (uint256 j = 0; j < voter.votes.length; j++) {
                if (voter.votes[j].recipientId == recipientId) {
                    hasAlreadyVoted = true;
                    recipientVotesCurrent -= voter.votes[j].amount;
                    voter.votes[j].amount = _votes[i].amount;

                    break;
                }
            }

            if (!hasAlreadyVoted) {
                voter.votes.push(CurrentVote(recipientId, _votes[i].amount));
            }

            uint96 recipientVotesNew = recipientVotesCurrent + _votes[i].amount;

            distributionPool.updateMemberUnits(
                _votes[i].recipient, recipientVotesNew
            );
            recipient.votes = recipientVotesNew;
            recipientById[recipientId] = recipient;
        }

        uint96 totalVotes;
        uint8 votingSpread;

        for (uint256 i = 0; i < voter.votes.length; i++) {
            if (
                recipientById[voter.votes[i].recipientId].account != address(0)
                    && voter.votes[i].amount != 0
            ) {
                votingSpread++;
            }

            totalVotes += voter.votes[i].amount;
        }

        if (totalVotes > voter.votingPower) {
            revert NOT_ENOUGH_VOTING_POWER();
        }

        if (maxVotingSpread > 0 && votingSpread > maxVotingSpread) {
            revert TOO_MUCH_VOTING_SPREAD();
        }

        emit Voted(msg.sender, _votes);
    }

    /**
     * @notice Gets a Recipients from the account address
     * @param _account The recipient address
     */
    function getRecipient(address _account)
        public
        view
        returns (Recipient memory recipient)
    {
        recipient = recipients[_account];
    }

    /**
     * @notice Gets a Voter from the account address
     * @param _account The voter address
     */
    function getVoter(address _account)
        public
        view
        returns (Voter memory voter)
    {
        voter = voters[_account];
    }

    /**
     * @notice Gets all current valid votes for a Voter
     * @param _account The voter address
     */
    function getVotes(address _account) public view returns (Vote[] memory) {
        Voter memory voter = voters[_account];

        uint256 validVotesCount;

        for (uint256 i = 0; i < voter.votes.length; i++) {
            Recipient memory recipient =
                recipientById[voter.votes[i].recipientId];

            if (recipient.account != address(0) && voter.votes[i].amount > 0) {
                validVotesCount++;
            }
        }

        Vote[] memory votes = new Vote[](validVotesCount);

        for (uint256 i = 0; i < voter.votes.length; i++) {
            Recipient memory recipient =
                recipientById[voter.votes[i].recipientId];

            if (recipient.account != address(0) && voter.votes[i].amount > 0) {
                votes[i] = Vote(recipient.account, voter.votes[i].amount);
            }
        }

        return votes;
    }
}
