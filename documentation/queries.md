# Flow Council Subgraph — Query Guide

A Flow Council is an onchain voting system that distributes funds via [Superfluid](https://superfluid.finance/) streaming. Voters allocate their voting power across recipients, and those votes determine each recipient's proportional share of a continuous token stream flowing through a Superfluid General Distribution Agreement (GDA) pool.

This guide covers how to query the Flow Council subgraph and related Superfluid data to build dashboards, reports, and integrations.

## Endpoints

| Resource | URL |
|----------|-----|
| Flow Council Playground | [Goldsky Explorer](https://api.goldsky.com/api/public/project_cmbkdj2bd7cr601uwafoe4u3y/subgraphs/flow-council-celo/v0.3.6/gn) |
| Flow Council API Endpoint | `https://api.goldsky.com/api/public/project_cmbkdj2bd7cr601uwafoe4u3y/subgraphs/flow-council-celo/v0.3.6/gn` |
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

You'll need these to construct query variables:

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
    metadata
    distributionPool
    superToken
    votersCount
    maxVotingSpread
    recipients {
      account
      metadata
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
            metadata
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

Get the current vote allocations for a specific recipient using `latestVotes`. Each entry is one voter's current allocation — no duplicates.

```graphql
query Recipient($recipientId: String!) {
  recipient(id: $recipientId) {
    account
    metadata
    latestVotes(first: 1000) {
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

Get the full history of votes received by a recipient. This *will* contain duplicate `votedBy` entries if a voter re-voted.

```graphql
query RecipientHistory($recipientId: String!) {
  recipient(id: $recipientId) {
    account
    metadata
    votes(first: 1000, orderBy: createdAtTimestamp, orderDirection: desc) {
      votedBy
      amount
      createdAtTimestamp
    }
  }
}
```

Variables:
```json
{
  "recipientId": "0xfabef1abae4998146e8a8422813eb787caa26ec2-0x5f3dd795ad9d626f5c0621b339a243220bcbd025"
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
        metadata
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

### All Ballots for a Specific Voter

```graphql
query VoterBallots($voterId: String!) {
  voter(id: $voterId) {
    account
    votingPower
    ballot {
      votes {
        recipient {
          account
          metadata
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

---

## Client-Side Aggregation Tips

The subgraph returns raw data — it doesn't compute aggregates. Here are common calculations you'll need to do client-side:

**Total votes per recipient** — Sum the `amount` field across all `latestVotes` for a recipient.

**Vote distribution percentages** — Divide each recipient's total votes by the sum of all recipients' totals.

**Unique voter count for a recipient** — Count distinct `votedBy` addresses in a recipient's `latestVotes`.

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
> `flowRate × 60 × 60 × 24 × 30 / 1e18`

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

Retrieve application metadata (profile info submitted by recipients) via the Flow State API.

**Endpoint:** `POST https://flowstate.network/api/flow-council/applications`

| Param | Type | Required |
|-------|------|----------|
| `chainId` | number | yes |
| `councilId` | string | yes |

```js
await fetch("https://flowstate.network/api/flow-council/applications", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    chainId: 42220,
    councilId: "0xfabef1abae4998146e8a8422813eb787caa26ec2",
  }),
});
```

You can also test this with [ReqBin](https://reqbin.com/) — paste the endpoint URL, set method to POST, and use body:
```json
{"chainId": 42220, "councilId": "0xfabef1abae4998146e8a8422813eb787caa26ec2"}
```

---

## Reference: GoodBuilders Season 3

### Addresses

| Resource | Address |
|----------|---------|
| Council | `0xfabef1abae4998146e8a8422813eb787caa26ec2` |
| Distribution Pool | `0xd56e85acdd6481c912c2020dff35e4207824aac2` |
| Super App (Stream Forwarder) | `0x496e247cc0dc5e707cc2684ae04e8e337637f3fa` |
| Super Token (G$) | `0x62b8b11039fcfe5ab0c56e502b1c372a3d2a9c7a` |

### Recipients

| Name | Address |
|------|---------|
| Balaio | `0x7c191ca3bc2eddcf295424958310fd5299ebe05b` |
| CANVASSING | `0x9cfa5c4bfe08a1a3f7c17d6503eeb23a0290c4ca` |
| Delulu | `0x5f3dd795ad9d626f5c0621b339a243220bcbd025` |
| Drip | `0xdb3a14f438ebf7a982c4372c8a17985b05f3a1ec` |
| Esusu | `0xb82896c4f251ed65186b416dbdb6f6192dfaf926` |
| FocusPet | `0xcb6f72152db12546b21ef0dd5f614ca532531838` |
| Gardens | `0xd7a3d3a7dd35b8e81fc0b83c032d0ed3261417d9` |
| Ubeswap | `0xddabeba1c309bf171cd5e60e863ca14cf84bf2e0` |
| Bitsave Protocol | `0x72578e136e72a18a832be6762230a820f514d180` |
| Sov Seas | `0xf7dbd2867f55832e4a05e16cd69cb57a70923cdd` |
| Pesia's Kitchen | `0xf8b4c7098d195d12c1336a09fddaa9afa11bd097` |

### Voter Categories

Voters are classified into three categories in the GoodBuilder Program. These classifications are **not stored onchain or in the subgraph** — they are maintained off-chain and used to balance voting power at the start of each epoch according to the following split:

| Category | Weight |
|----------|--------|
| Mentor | 50% |
| Metrics | 25% |
| Community | 25% |

**Metrics** (1 voter):
- `0x7F0a04F131B8395e4e0bCf4c77E47845c952f49D`

**Mentor** (12 voters):
- `0x9F6c0aC954829A863e8d09a46A7A167D5763975c`
- `0x6fb2ed5113e686cd9fe3405203d9dead9d1a3384`
- `0x86213f1cf0a501857B70Df35c1cb3C2EcF112844`
- `0xf62daae4c3f9fadf689f767716a82dfee5026c89`
- `0x6e7679d53C43a8A9E2cf87fCA99a1DB9B379FE29`
- `0x6eeb37b9757dca963120f61c7e0e0160469a44d3`
- `0x884Ff907D5fB8BAe239B64AA8aD18bA3f8196038`
- `0x31cd90C2788f3e390d2Bb72871f5aD3F1a4B22a1`
- `0xA48840D89a761502A4a7d995c74f3864D651A87F`
- `0x3B7275C428c9B46D2c244E066C0bbadB9B9a8B9f`
- `0xF3d4eF9c67bbdb40e7a16975a8a8A4D8e41Df8D9`
- `0xA50064D462e17f7091eE62BaebeB18BFEBE21507`

**Community:** All remaining voters not listed above.

Dashboard builders may find these classifications useful for further analyzing vote distribution across different personas.

### Epoch Schedule

Epochs are the two-week cadence of the GoodBuilders program. In each epoch, new votes are assigned, demo days are held, and recipients submit their milestones/updates.

Epoch 1 (ends 2026-03-04 12:00:00 UTC)
```json
{
  "epochEnd": 1772625600
}
```

Epoch 2 (2026-03-04 12:00:01 – 2026-03-18 12:00:00 UTC)
```json
{
  "epochStart": 1772625601,
  "epochEnd": 1773835200
}
```

Epoch 3 (2026-03-18 12:00:01 – 2026-04-01 12:00:00 UTC)
```json
{
  "epochStart": 1773835201,
  "epochEnd": 1775044800
}
```

Epoch 4 (2026-04-01 12:00:01 – 2026-04-15 12:00:00 UTC)
```json
{
  "epochStart": 1775044801,
  "epochEnd": 1776254400
}
```

Epoch 5 (2026-04-15 12:00:01 – 2026-04-29 12:00:00 UTC)
```json
{
  "epochStart": 1776254401,
  "epochEnd": 1777464000
}
```

Epoch 6 (2026-04-29 12:00:01 – 2026-05-13 12:00:00 UTC)
```json
{
  "epochStart": 1777464001,
  "epochEnd": 1778673600
}
```
