# Flow Council

Flow Council is a voting system that enables organizations to dynamically stream funds among recipients based on weighted votes.

## Architecture

The system consists of two main contracts:

### FlowCouncilFactory.sol
A lightweight factory contract for deploying new FlowCouncil instances.

### FlowCouncil.sol
The contract that manages voters, recipients, and vote processing.

**Core Features:**
- **Role-based Access Control**: Uses OpenZeppelin's AccessControl with specialized roles
- **Superfluid Integration**: Automatically distributes funds via Superfluid pools based on vote weights
- **Vote Management**: Efficient vote storage and processing
- **Dynamic Membership**: Add/remove voters and recipients with proper vote cleanup

## How It Works

1. **Setup**: Deploy FlowCouncil via factory, configure initial admin
2. **Role Assignment**: Admin grants `VOTER_MANAGER_ROLE` and `RECIPIENT_MANAGER_ROLE`
3. **Member Management**: Managers add voters (with voting power) and recipients
4. **Voting Process**: Voters cast their votes across recipients
5. **Automatic Distribution**: Superfluid pool distributes streaming funds proportionally

## Access Control

- **`DEFAULT_ADMIN_ROLE`**: Can manage all roles and system parameters
- **`VOTER_MANAGER_ROLE`**: Can add, remove, and edit voters
- **`RECIPIENT_MANAGER_ROLE`**: Can add, remove, and manage recipients

## Contract Deployment

### Networks

<table>
<thead>
    <tr>
        <th>Chain</th>
        <th>Chain ID</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>Optimism Sepolia</td>
        <td>11155420</td>
    </tr>
</tbody>
</table>

### Address

<table>
<thead>
    <tr>
        <th>Contract</th>
        <th>Address</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>Council Factory</td>
        <td>0x46a2496c9df5c00ccc51bcb9b77345410718de26</td>
    </tr>
</tbody>
</table>

## Development

The project uses Foundry for development and testing:

```bash
# Install dependencies
forge install

# Run tests
forge test
```
