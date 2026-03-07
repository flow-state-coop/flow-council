# Flow Council Subgraph — Query Guide

A Flow Council is an onchain voting system that distributes funds via [Superfluid](https://superfluid.finance/) streaming. Voters allocate their voting power across recipients, and those votes determine each recipient's proportional share of a continuous token stream flowing through a Superfluid General Distribution Agreement (GDA) pool.

This guide covers how to query the Flow Council subgraph and related Superfluid data to build dashboards, reports, and integrations.

## Endpoints

| Resource | URL |
|----------|-----|
| Flow Council Playground | [Goldsky Explorer](https://api.goldsky.com/api/public/project_cmbkdj2bd7cr601uwafoe4u3y/subgraphs/flow-council-celo/v0.3.7/gn) |
| Flow Council API Endpoint | `https://api.goldsky.com/api/public/project_cmbkdj2bd7cr601uwafoe4u3y/subgraphs/flow-council-celo/v0.3.7/gn` |
| Superfluid Playground | [Superfluid Explorer](https://explorer.superfluid.org/subgraph) *(select Celo network)* |
| Superfluid API Endpoint | `https://subgraph-endpoints.superfluid.dev/celo-mainnet/protocol-v1` |

---

## Data Model

### How It Works

```
Funders ──stream──▶ Super App ──distributes──▶ Distribution Pool ──streams──▶ Recipients
                                                       ▲
                                              Votes determine each
                                              recipient's share
```

1. **Funders** open Superfluid streams to a Super App contract
2. The **Super App** forwards the aggregated stream into a **Distribution Pool** (GDA)
3. **Voters** cast ballots allocating their voting power across recipients
4. Each **recipient's** share of the pool is proportional to the votes they receive

### Entities

```
FlowCouncil
├── Voter (has votingPower, casts Ballots)
│   ├── Ballot (a voter's complete vote submission)
│   │   └── Vote (individual allocation: recipient + amount)
│   └── LatestVote (current allocation snapshot per recipient)
├── Recipient (receives votes, gets stream share)
└── FlowCouncilManager (admin role holder)
```

| Entity | What it represents |
|--------|--------------------|
| **FlowCouncil** | A council instance — holds config, links to all voters/recipients |
| **Voter** | A participant with voting power who can cast ballots |
| **Recipient** | An account that receives votes and a proportional share of the stream |
| **Ballot** | A single vote transaction — captures all of a voter's allocations at once |
| **Vote** | One voter → one recipient allocation within a ballot (historical record) |
| **LatestVote** | The *current* allocation from a voter to a recipient (updated in place) |
| **FlowCouncilManager** | An account holding a VOTER_MANAGER_ROLE or RECIPIENT_MANAGER_ROLE |

### Vote vs. LatestVote

These two entities serve different purposes:

- **Vote** — An append-only historical log. Every time a voter submits a ballot, new Vote records are created. Use this when you need vote history over time.
- **LatestVote** — A snapshot of the current state. When a voter re-votes, their LatestVote is updated in place. Use this when you need current standings.

### Entity ID Formats

You'll need these to construct query variables. **All addresses must be lowercase** — the subgraph stores IDs in lowercase and lookups are case-sensitive.

| Entity | ID Format | Example |
|--------|-----------|---------|
| FlowCouncil | `{councilAddress}` | `0xfabe...c2` |
| Voter | `{councilAddress}-{voterAddress}` | `0xfabe...c2-0x1234...ef` |
| Recipient | `{councilAddress}-{recipientAddress}` | `0xfabe...c2-0x5f3d...25` |
| Ballot | `{txHash}-{logIndex}` | `0xabcd...01-5` |
| Vote | `{voterAddress}-{recipientAddress}-{timestamp}` | `0x1234...ef-0x5f3d...25-1772625601` |
| LatestVote | `{councilAddress}-{voterAddress}-{recipientAddress}` | `0xfabe...c2-0x1234...ef-0x5f3d...25` |
| FlowCouncilManager | `{councilAddress}-{roleHash}-{accountAddress}` | `0xfabe...c2-0xe39c...48-0x1234...ef` |

---

## Query Cookbook

All queries below run against the **Flow Council subgraph** unless noted otherwise. Paste the query into the top pane of the playground and variables into the bottom pane.

### Council Overview

Get a council's configuration, voter count, and recipient list.

```graphql
query FlowCouncil($councilId: String!) {
  flowCouncil(id: $councilId) {
    distributionPool
    superToken
    votersCount
    maxVotingSpread
    recipients {
      account
    }
    createdAtTimestamp
  }
}
```

Variables:
```json
{
  "councilId": "0xfabef1abae4998146e8a8422813eb787caa26ec2"
}
```

### Voters with Current Ballots

List voters and how they've allocated their votes. The `ballot` field is the voter's most recent vote submission.

```graphql
query Voters($councilId: String!) {
  flowCouncil(id: $councilId) {
    votersCount
    voters(first: 1000) {
      account
      votingPower
      ballot {
        votes {
          recipient {
            account
          }
          amount
        }
        createdAtTimestamp
      }
    }
  }
}
```

Variables:
```json
{
  "councilId": "0xfabef1abae4998146e8a8422813eb787caa26ec2"
}
```

> **Pagination note:** `first: 1000` is the subgraph maximum. For councils with more than 1000 voters, paginate using `skip`:
> ```graphql
> voters(first: 1000, skip: 1000) { ... }
> ```

### Recipient Standings (Current Votes)

Get the current vote allocations for a specific recipient. Each entry is one voter's current allocation — no duplicates.

```graphql
query Recipient($recipientId: String!) {
  recipient(id: $recipientId) {
    account
    votes(first: 1000) {
      votedBy
      amount
      createdAtTimestamp
    }
  }
}
```

Variables (ID format: `{councilAddress}-{recipientAddress}`):
```json
{
  "recipientId": "0xfabef1abae4998146e8a8422813eb787caa26ec2-0x5f3dd795ad9d626f5c0621b339a243220bcbd025"
}
```

### Recipient Vote History

Get the full history of votes received by a specific recipient. Historical `Vote` records are stored on `Ballot` entities, so query them via `votes` with a `recipient` filter. This *will* contain duplicate `votedBy` entries if a voter re-voted.

```graphql
query RecipientHistory($recipientAddress: Bytes!) {
  votes(
    first: 1000
    orderBy: createdAtTimestamp
    orderDirection: desc
    where: {recipient_: {account: $recipientAddress}}
  ) {
    votedBy
    amount
    createdAtTimestamp
  }
}
```

Variables:
```json
{
  "recipientAddress": "0x5f3dd795ad9d626f5c0621b339a243220bcbd025"
}
```

### Ballots in a Time Range

Query all ballots submitted within an epoch or arbitrary time window.

```graphql
query Ballots($epochStart: BigInt, $epochEnd: BigInt) {
  ballots(
    orderBy: createdAtTimestamp
    orderDirection: asc
    first: 1000
    where: {createdAtTimestamp_gte: $epochStart, createdAtTimestamp_lt: $epochEnd}
  ) {
    createdAtTimestamp
    voter {
      account
      votingPower
    }
    votes {
      amount
      recipient {
        account
      }
      votedBy
    }
  }
}
```

Variables:
```json
{
  "epochStart": 1772625601,
  "epochEnd": 1773835200
}
```

### Current Ballot for a Specific Voter

The `ballot` field on `Voter` is singular — it always points to the voter's most recent ballot.

```graphql
query VoterCurrentBallot($voterId: String!) {
  voter(id: $voterId) {
    account
    votingPower
    ballot {
      votes {
        recipient {
          account
        }
        amount
      }
      createdAtTimestamp
    }
  }
}
```

Variables (ID format: `{councilAddress}-{voterAddress}`):
```json
{
  "voterId": "0xfabef1abae4998146e8a8422813eb787caa26ec2-0x22705489ca3b4c7e3bed63c9fe5d6660aa945f90"
}
```

### All Ballots for a Specific Voter

To get a voter's full ballot history, query top-level `ballots` with a voter filter.

```graphql
query VoterBallotHistory($voterId: String!) {
  ballots(
    first: 1000
    orderBy: createdAtTimestamp
    orderDirection: desc
    where: {voter: $voterId}
  ) {
    votes {
      recipient {
        account
      }
      amount
    }
    createdAtTimestamp
  }
}
```

Variables (ID format: `{councilAddress}-{voterAddress}`):
```json
{
  "voterId": "0xfabef1abae4998146e8a8422813eb787caa26ec2-0x22705489ca3b4c7e3bed63c9fe5d6660aa945f90"
}
```

### Council Managers

List accounts with admin roles on a council.

```graphql
query Managers($councilId: String!) {
  flowCouncil(id: $councilId) {
    flowCouncilManagers {
      account
      role
    }
  }
}
```

### Reconstruct Allocations at a Past Time

The subgraph doesn't store historical snapshots — `LatestVote` is updated in place. To reconstruct allocations at a specific past time, fetch all historical `Vote` records up to that timestamp and deduplicate client-side.

```graphql
query VotesAtTime($councilId: String!, $timestamp: BigInt!) {
  ballots(
    first: 1000
    orderBy: createdAtTimestamp
    orderDirection: desc
    where: {flowCouncil: $councilId, createdAtTimestamp_lte: $timestamp}
  ) {
    voter {
      account
    }
    votes {
      recipient {
        account
      }
      amount
    }
    createdAtTimestamp
  }
}
```

Variables:
```json
{
  "councilId": "0xfabef1abae4998146e8a8422813eb787caa26ec2",
  "timestamp": 1772625600
}
```

**Client-side reconstruction:** For each voter, keep only their most recent ballot (the first one encountered since results are ordered desc). That ballot's votes represent their allocations at that point in time. Discard earlier ballots from the same voter.

---

## Client-Side Aggregation Tips

The subgraph returns raw data — it doesn't compute aggregates. Here are common calculations you'll need to do client-side:

**Total votes per recipient** — Sum the `amount` field across all `votes` for a recipient.

**Vote distribution percentages** — Divide each recipient's total votes by the sum of all recipients' totals.

**Unique voter count for a recipient** — Count distinct `votedBy` addresses in a recipient's `votes`.

**Active vs. inactive voters** — Voters with a non-null `ballot` have voted at least once. Compare against `votersCount` for participation rate.

**Stream share per recipient** — A recipient's share of the total stream equals their vote percentage. If a recipient has 30% of total votes, they receive 30% of the flow rate through the distribution pool.

---

## Superfluid Pool & Funding Queries

These queries run on the **[Superfluid subgraph](https://explorer.superfluid.org/subgraph)** (select **Celo** network).

### Architecture: Super App as Stream Forwarder

Funders don't stream directly to the distribution pool. Instead, a **Super App** contract sits in between:

```
Funder A ──stream──┐
Funder B ──stream──┤──▶ Super App ──distributes──▶ Distribution Pool ──▶ Recipients
Funder C ──stream──┘
```

This means:
- The **distribution pool** has only **one distributor** — the Super App
- To see individual funders and their flow rates, query **streams into the Super App**

### Pool Distributor (Total Flow Rate)

This returns the Super App as the single distributor with the aggregate flow rate into the pool.

```graphql
query PoolDistributor($poolId: String!) {
  pool(id: $poolId) {
    poolDistributors(first: 10) {
      flowRate
      account {
        id
      }
      createdAtTimestamp
    }
  }
}
```

Variables:
```json
{
  "poolId": "0xd56e85acdd6481c912c2020dff35e4207824aac2"
}
```

> The `flowRate` is in **wei per second**. To convert to tokens per month:
> `flowRate × 60 × 60 × 24 × (365 / 12) / 1e18`

### Individual Funders (Streams to Super App)

To see who is actually funding the council and their individual flow rates, query streams where the receiver is the Super App:

```graphql
query Funders($superApp: String!) {
  streams(
    where: {receiver: $superApp, currentFlowRate_gt: "0"}
    first: 1000
    orderBy: createdAtTimestamp
    orderDirection: desc
  ) {
    sender {
      id
    }
    currentFlowRate
    token {
      symbol
    }
    createdAtTimestamp
  }
}
```

Variables:
```json
{
  "superApp": "0x496e247cc0dc5e707cc2684ae04e8e337637f3fa"
}
```

> The `currentFlowRate_gt: "0"` filter excludes closed streams. Remove it to see all streams including historical ones.

### Recipient Pool Members (Superfluid Explorer)

For a quick view of recipient shares and total streamed amounts, visit the distribution pool directly in the Superfluid Explorer:

[Pool Explorer View](https://explorer.superfluid.org/celo/pools/0xd56e85acdd6481c912c2020dff35e4207824aac2)

The `getTotalAmountReceivedByMember()` function on the [Distribution Pool contract](https://celoscan.io/address/0xd56e85acdd6481c912c2020dff35e4207824aac2#readProxyContract#F11) returns exact totals streamed per recipient — this is more accurate than computing from flow rates and time.

---

## Flow Council Applications API

This is the **source of truth for recipient profile data** (name, description, social links, etc.). The subgraph only stores recipient addresses — use this API for all profile/metadata information.

**Endpoint:** `GET https://flowstate.network/api/flow-council/applications/public`

| Param | Type | Required |
|-------|------|----------|
| `chainId` | number | yes |
| `councilId` | string | yes |

```js
const params = new URLSearchParams({
  chainId: "42220",
  councilId: "0xfabef1abae4998146e8a8422813eb787caa26ec2",
});

await fetch(
  `https://flowstate.network/api/flow-council/applications/public?${params}`
);
```

You can also test this directly in your browser or with curl:
```bash
curl "https://flowstate.network/api/flow-council/applications/public?chainId=42220&councilId=0xfabef1abae4998146e8a8422813eb787caa26ec2"
```
