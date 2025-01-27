# DecideX: Decentralized Prediction Markets on Stacks

DecideX is a smart contract platform that enables users to create and participate in decentralized prediction markets on the Stacks blockchain. Users can create markets, place bets on outcomes, and earn rewards for correct predictions.

## Features

- Create prediction markets with customizable descriptions and expiry times
- Place bets on binary outcomes (true/false)
- Automatic reward distribution for winning bets
- Built-in platform fee mechanism
- Emergency shutdown capability for contract maintenance
- Refund mechanism for expired, unresolved markets

## Technical Specifications

- Minimum bet: 1000 microSTX (0.001 STX)
- Maximum bet: 1,000,000,000 microSTX (1000 STX)
- Platform fee: 100 microSTX (0.0001 STX) per bet
- Market expiry: Between 100 and 52,560 blocks (approximately 1 year maximum)
- Description length: 1-100 ASCII characters

## Contract Functions

### Public Functions

- `create-market`: Create a new prediction market
- `place-bet`: Place a bet on a market outcome
- `resolve-market`: Resolve a market (creator only)
- `claim-winnings`: Claim winnings for correct predictions
- `refund-bet`: Get a refund for expired, unresolved markets
- `transfer-ownership`: Transfer contract ownership (owner only)
- `toggle-shutdown`: Emergency shutdown toggle (owner only)

### Read-Only Functions

- `get-market-details`: Get comprehensive market information
- `calculate-potential-winnings`: Calculate potential returns for a bet
- `is-shutdown`: Check if emergency shutdown is active

## Error Codes

| Code | Description |
|------|-------------|
| 100  | Not market creator |
| 101  | Market already resolved |
| 102  | Market not resolved |
| 103  | Invalid bet |
| 104  | Insufficient balance |
| 105  | Market expired |
| 106  | Refund not allowed |
| 107  | Not authorized |
| 108  | Shutdown active |
| 109  | Invalid expiry |
| 110  | Invalid amount |
| 111  | Invalid owner |
| 112  | Invalid market ID |
| 113  | Invalid description |

## Getting Started

1. Deploy the contract to the Stacks blockchain
2. Call `create-market` to create your first prediction market
3. Users can place bets using `place-bet`
4. Market creator resolves the market using `resolve-market`
5. Winners can claim rewards using `claim-winnings`

## Security Considerations

- All inputs are validated before processing
- Contract includes emergency shutdown mechanism
- Built-in checks for market expiry and resolutions
- Protected functions for administrative actions
- Validated string inputs for market descriptions

## Testing

To run the contract tests:

```bash
clarinet test
```

## License

MIT

---

## Pull Request Description

### DecideX: Implementation of Decentralized Prediction Markets

#### Changes Made
- Implemented core prediction market functionality
- Added comprehensive input validation
- Implemented fee collection mechanism
- Added emergency shutdown capability
- Created market lifecycle management
- Added betting and reward distribution system

#### Key Features
- Binary outcome markets (true/false)
- Configurable market expiry
- Automated winner payment distribution
- Built-in platform fee collection
- Emergency shutdown mechanism
- Refund system for expired markets

#### Security Considerations
- Added input validation for all public functions
- Implemented proper access controls
- Added checks for market state transitions
- Validated string inputs
- Protected against common attack vectors


#### Dependencies
- Clarity language
- Stacks blockchain

#### Next Steps
- Deploy to testnet
- Conduct security audit
- Create frontend interface
- Add documentation for API integration