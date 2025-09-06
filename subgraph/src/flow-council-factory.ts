import { ethereum, crypto, Bytes } from "@graphprotocol/graph-ts";
import { FlowCouncilCreated as FlowCouncilCreatedEvent } from "../generated/FlowCouncilFactory/FlowCouncilFactory";
import { FlowCouncil } from "../generated/schema";
import { FlowCouncil as FlowCouncilTemplate } from "../generated/templates";
import { FlowCouncil as FlowCouncilContract } from "../generated/templates/FlowCouncil/FlowCouncil";

export function handleFlowCouncilCreated(event: FlowCouncilCreatedEvent): void {
  const flowCouncilAddress = event.params.flowCouncil;
  const entity = new FlowCouncil(event.params.flowCouncil.toHex());
  const voterManagerRole = Bytes.fromByteArray(
    crypto.keccak256(Bytes.fromUTF8("VOTER_MANAGER_ROLE")),
  );
  const recipientManagerRole = Bytes.fromByteArray(
    crypto.keccak256(Bytes.fromUTF8("RECIPIENT_MANAGER_ROLE")),
  );

  const flowCouncilContract = FlowCouncilContract.bind(flowCouncilAddress);

  entity.metadata = event.params.metadata;
  entity.distributionPool = event.params.distributionPool;
  entity.voterManagerRole = voterManagerRole;
  entity.recipientManagerRole = recipientManagerRole;
  entity.distributionPool = event.params.distributionPool;
  entity.superToken = flowCouncilContract.superToken();
  entity.maxVotingSpread = flowCouncilContract.maxVotingSpread();
  entity.votersCount = 0;
  entity.createdAtBlock = event.block.number;
  entity.createdAtTimestamp = event.block.timestamp;

  entity.save();

  FlowCouncilTemplate.create(flowCouncilAddress);
}
