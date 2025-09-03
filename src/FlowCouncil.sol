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
     * @notice Maps the voter address to a Voter
     */
    mapping(address => Voter) public voters;

    bytes32 public constant RECIPIENT_MANAGER_ROLE =
        keccak256("RECIPIENT_MANAGER_ROLE");
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
    function addRecipient(address _account) public onlyRecipientManager {
        Recipient storage recipient = recipients[_account];

        if (recipient.account != address(0)) {
            revert ALREADY_ADDED(_account);
        }

        recipient.account = _account;
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
        distributionPool.updateMemberUnits(_account, 0);
    }

    /**
     * @notice Updates the flow council recipients
     * @param _recipients The recipients to add or remove
     */
    function updateRecipients(UpdatingAccount[] calldata _recipients)
        external
        onlyRecipientManager
    {
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_recipients[i].status == Status.Removed) {
                removeRecipient(_recipients[i].account);
            } else {
                addRecipient(_recipients[i].account);
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
            distributionPool.updateMemberUnits(voter.votes[i].recipient, 0);
        }

        delete voters[_account];
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

        maxVotingSpread = _maxVotingSpread;
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
}
