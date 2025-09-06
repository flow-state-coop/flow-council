import { BigInt } from "@graphprotocol/graph-ts";
import { log, store } from "@graphprotocol/graph-ts";
import {
  Ballot,
  FlowCouncil,
  Voter,
  Recipient,
  FlowCouncilManager,
  Vote,
  LatestVote,
} from "../generated/schema";
import {
  RoleGranted,
  RoleRevoked,
  Voted,
  VoterAdded,
  VoterRemoved,
  VoterEdited,
  RecipientAdded,
  RecipientRemoved,
  MaxVotingSpreadSet,
} from "../generated/templates/FlowCouncil/FlowCouncil";

export function handleRoleGranted(event: RoleGranted): void {
  const flowCouncilManager = new FlowCouncilManager(
    `${event.address.toHex()}-${event.params.role.toHex()}-${event.params.account.toHex()}`
  );
  const flowCouncil = FlowCouncil.load(event.address.toHex());

  if (!flowCouncil) {
    log.warning("Flow Council not found for role {} and account {}", [
      event.params.role.toHex(),
      event.params.account.toHex(),
    ]);

    return;
  }

  flowCouncilManager.account = event.params.account;
  flowCouncilManager.role = event.params.role;
  flowCouncilManager.flowCouncil = flowCouncil.id;
  flowCouncilManager.createdAtBlock = event.block.number;
  flowCouncilManager.createdAtTimestamp = event.block.timestamp;

  flowCouncilManager.save();
}

export function handleRoleRevoked(event: RoleRevoked): void {
  const id = `${event.address.toHex()}-${event.params.role.toHex()}-${event.params.account.toHex()}`;

  store.remove("FlowCouncilManager", id);
}

export function handleVoterAdded(event: VoterAdded): void {
  const flowCouncilId = event.address.toHex();
  const voter = new Voter(`${flowCouncilId}-${event.params.account.toHex()}`);
  const flowCouncil = FlowCouncil.load(flowCouncilId);

  if (!flowCouncil) {
    log.warning("Flow Council not found for voter {}, flow council {}", [
      event.params.account.toHex(),
      flowCouncilId,
    ]);

    return;
  }

  voter.account = event.params.account;
  voter.votingPower = event.params.votingPower;
  voter.flowCouncil = flowCouncilId;
  voter.createdAtTimestamp = event.block.timestamp;
  voter.createdAtBlock = event.block.number;
  flowCouncil.votersCount = flowCouncil.votersCount + 1;

  voter.save();
  flowCouncil.save();
}

export function handleVoterRemoved(event: VoterRemoved): void {
  const flowCouncilId = event.address.toHex();
  const voterId = `${flowCouncilId}-${event.params.account.toHex()}`;
  const flowCouncil = FlowCouncil.load(flowCouncilId);

  if (!flowCouncil) {
    log.warning("Flow Council not found for voter {}, flow council {}", [
      event.params.account.toHex(),
      flowCouncilId,
    ]);

    return;
  }

  flowCouncil.votersCount = flowCouncil.votersCount - 1;

  store.remove("Voter", voterId);
  flowCouncil.save();
}

export function handleVoterEdited(event: VoterEdited): void {
  const voterId = `${event.address.toHex()}-${event.params.account.toHex()}`;
  const voter = Voter.load(voterId);

  if (!voter) {
    log.warning("Voter not found for id {}", [voterId]);

    return;
  }

  voter.votingPower = event.params.votingPower;

  voter.save();
}

export function handleRecipientAdded(event: RecipientAdded): void {
  const recipient = new Recipient(
    `${event.address.toHex()}-${event.params.account.toHex()}`
  );
  recipient.metadata = event.params.metadata;
  recipient.account = event.params.account;
  recipient.flowCouncil = event.address.toHex();
  recipient.createdAtTimestamp = event.block.timestamp;
  recipient.createdAtBlock = event.block.number;

  recipient.save();
}

export function handleRecipientRemoved(event: RecipientRemoved): void {
  const recipientId = `${event.address.toHex()}-${event.params.account.toHex()}`;

  store.remove("Recipient", recipientId);
}

export function handleVoted(event: Voted): void {
  const ballot = new Ballot(
    `${event.transaction.hash.toHex()}-${event.logIndex.toString()}`
  );
  const voter = Voter.load(
    `${event.address.toHex()}-${event.params.account.toHex()}`
  );

  if (!voter) {
    log.warning("Voter not found, skipping allocation", [
      event.params.account.toHex(),
    ]);
    return;
  }

  ballot.flowCouncil = event.address.toHex();
  ballot.voter = voter.id;
  ballot.createdAtBlock = event.block.number;
  ballot.createdAtTimestamp = event.block.timestamp;

  const votes: string[] = [];

  for (let i = 0; i < event.params.votes.length; i++) {
    const recipient = Recipient.load(
      `${event.address.toHex()}-${event.params.votes[i].recipient.toHex()}`
    );

    if (!recipient) {
      log.warning("Not all recipients found, skipping allocation", [
        event.params.votes[i].recipient.toHex(),
      ]);
      return;
    }

    const vote = new Vote(
      `${event.params.account.toHex()}-${recipient.account.toHex()}-${
        event.block.timestamp
      }`
    );

    vote.recipient = recipient.id;
    vote.votedBy = event.params.account;
    vote.amount = event.params.votes[i].amount;
    vote.createdAtBlock = event.block.number;
    vote.createdAtTimestamp = event.block.timestamp;

    vote.save();
    votes.push(vote.id);

    const latestVoteId = `${event.address.toHex()}-${event.params.account.toHex()}-${recipient.account.toHex()}`;

    let latestVote = LatestVote.load(latestVoteId);

    if (!latestVote) {
      latestVote = new LatestVote(latestVoteId);
    }

    latestVote.recipient = recipient.id;
    latestVote.votedBy = event.params.account;
    latestVote.amount = event.params.votes[i].amount;
    latestVote.createdAtBlock = event.block.number;
    latestVote.createdAtTimestamp = event.block.timestamp;

    latestVote.save();
  }

  ballot.votes = votes;
  ballot.save();

  voter.ballot = ballot.id;
  voter.save();
}

export function handleMaxVotingSpreadSet(event: MaxVotingSpreadSet): void {
  const flowCouncil = FlowCouncil.load(event.address.toHex());

  if (flowCouncil) {
    flowCouncil.maxVotingSpread = event.params.maxVotingSpread;
    flowCouncil.save();
  }
}
