# GoodBuilders Season 3 Reference

Program-specific reference data for the GoodBuilders Season 3 deployment on Celo.

## Addresses

| Resource | Address |
|----------|---------|
| Council | `0xfabef1abae4998146e8a8422813eb787caa26ec2` |
| Distribution Pool | `0xd56e85acdd6481c912c2020dff35e4207824aac2` |
| Super App (Stream Forwarder) | `0x496e247cc0dc5e707cc2684ae04e8e337637f3fa` |
| Super Token (G$) | `0x62b8b11039fcfe5ab0c56e502b1c372a3d2a9c7a` |

## Recipients

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

## Voter Categories

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

### Voter Category Breakdown

To analyze votes by category, fetch all voters with their current ballots using the [Voters with Current Ballots](queries.md#voters-with-current-ballots) query, then classify each voter client-side:

```js
const METRICS = new Set([
  "0x7f0a04f131b8395e4e0bcf4c77e47845c952f49d",
]);

const MENTORS = new Set([
  "0x9f6c0ac954829a863e8d09a46a7a167d5763975c",
  "0x6fb2ed5113e686cd9fe3405203d9dead9d1a3384",
  "0x86213f1cf0a501857b70df35c1cb3c2ecf112844",
  "0xf62daae4c3f9fadf689f767716a82dfee5026c89",
  "0x6e7679d53c43a8a9e2cf87fca99a1db9b379fe29",
  "0x6eeb37b9757dca963120f61c7e0e0160469a44d3",
  "0x884ff907d5fb8bae239b64aa8ad18ba3f8196038",
  "0x31cd90c2788f3e390d2bb72871f5ad3f1a4b22a1",
  "0xa48840d89a761502a4a7d995c74f3864d651a87f",
  "0x3b7275c428c9b46d2c244e066c0bbadb9b9a8b9f",
  "0xf3d4ef9c67bbdb40e7a16975a8a8a4d8e41df8d9",
  "0xa50064d462e17f7091ee62baebeb18bfebe21507",
]);

function categorize(voterAddress) {
  const addr = voterAddress.toLowerCase();
  if (METRICS.has(addr)) return "metrics";
  if (MENTORS.has(addr)) return "mentor";
  return "community";
}

// Group votes by category, then aggregate per recipient
const votesByCategory = { mentor: {}, metrics: {}, community: {} };
for (const voter of voters) {
  const category = categorize(voter.account);
  if (!voter.ballot) continue;
  for (const vote of voter.ballot.votes) {
    const recipient = vote.recipient.account;
    votesByCategory[category][recipient] =
      (votesByCategory[category][recipient] || 0n) + BigInt(vote.amount);
  }
}
```

This lets you answer questions like "How did mentors vote vs. community?" or compute category-weighted scores that reflect the 50/25/25 split used for voting power balancing.

## Epoch Schedule

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
