// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title FlowCouncil Interface
 * @notice Interface for the FlowCouncil contract.
 */
interface IFlowCouncil {
    /**
     * @notice The manager structure
     */
    struct Manager {
        address account;
        bytes32 role;
        Status status;
    }

    /**
     * @notice The voter structure
     */
    struct Voter {
        address account;
        uint96 votingPower;
        CurrentVote[] votes;
    }

    /**
     * @notice The manager structure
     */
    struct Recipient {
        address account;
        uint96 votes;
    }

    /**
     * @notice The vote structure
     */
    struct Vote {
        address recipient;
        uint96 amount;
    }

    /**
     * @notice The current votes casted by a voter
     * @dev The recipient id to validate the votes for recipients that were
     * not removed
     */
    struct CurrentVote {
        uint160 recipientId;
        uint96 amount;
    }

    /**
     * @notice The structure to represent an account which status needs to be
     * updated
     */
    struct UpdatingAccount {
        address account;
        Status status;
    }

    /**
     * @notice The status an account should have
     */
    enum Status {
        Added,
        Removed
    }
    /**
     * @notice Throws when the caller does not have the necessary role
     */

    error UNAUTHORIZED();

    /**
     * @notice Thrown as a general error when input / data is invalid
     */
    error INVALID();

    /**
     * @notice Thrown when the account was already added
     */
    error ALREADY_ADDED(address account);

    /**
     * @notice Thrown when the account was not found
     */
    error NOT_FOUND(address account);

    /**
     * @notice Thrown when the voting power is not enough
     */
    error NOT_ENOUGH_VOTING_POWER();

    /**
     * @notice Thrown when the voting spread is too much
     */
    error TOO_MUCH_VOTING_SPREAD();
}
