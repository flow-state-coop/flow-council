// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title FlowCouncil Interface
 * @notice Interface for the FlowCouncil contract.
 */
interface IFlowCouncil {
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

    struct Manager {
        address account;
        bytes32 role;
        Status status;
    }

    struct Voter {
        address account;
        uint96 votingPower;
        Vote[] votes;
    }

    struct Recipient {
        address account;
        uint96 votes;
    }

    struct Vote {
        address recipient;
        uint96 amount;
    }

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
}
