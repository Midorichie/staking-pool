# Enhanced STX Staking Pool

A secure and feature-rich Stacks (STX) staking pool smart contract with governance functionality built with Clarity.

## 🚀 Features

### Phase 1 (Initial Implementation)
- Basic STX staking functionality
- Reward calculation based on staking duration
- Simple claim mechanism

### Phase 2 (Enhanced Version)
- **🐛 Bug Fixes**: Fixed integer division bug causing zero rewards
- **🔒 Security Enhancements**: Added access controls, input validation, and emergency functions
- **⚡ New Functionality**: 
  - Add to existing stakes
  - Claim rewards without unstaking
  - Emergency unstaking
  - Contract funding mechanism
- **🏛️ Governance Contract**: Decentralized parameter control through voting
- **📊 Enhanced Monitoring**: Comprehensive read-only functions for contract state

## 📋 Contract Overview

### Staking Pool Contract (`staking-pool.clar`)

#### Key Features
- **Minimum Stake**: Configurable minimum staking amount (default: 1 STX)
- **Reward Rate**: Configurable reward rate (default: 1% per 1000 blocks)
- **Precise Calculations**: Enhanced reward calculation to prevent zero rewards
- **Emergency Controls**: Contract pause functionality and emergency unstaking
- **Compound Functionality**: Add to existing stakes without losing rewards

#### Main Functions

**Staking Functions**
- `stake(amount)` - Stake STX tokens
- `add-stake(amount)` - Add to existing stake
- `claim-rewards()` - Claim rewards without unstaking
- `unstake()` - Unstake with rewards
- `emergency-unstake()` - Emergency unstake (principal only)

**Admin Functions**
- `set-reward-rate(rate)` - Update reward rate (owner only)
- `set-min-stake(amount)` - Update minimum stake (owner only)
- `toggle-contract(active)` - Pause/unpause contract (owner only)
- `fund-contract(amount)` - Add STX for reward payments (owner only)

**Read-Only Functions**
- `get-staker-info(principal)` - Get staker details
- `get-pending-rewards(principal)` - Calculate pending rewards
- `get-contract-stats()` - Get contract statistics

### Governance Contract (`governance.clar`)

#### Features
- **Proposal System**: Stakers can propose parameter changes
- **Voting Mechanism**: Vote weight based on staked amount
- **Time-bound Voting**: Configurable voting periods
- **Execution Control**: Automated execution of passed proposals

#### Proposal Types
1. **Reward Rate Changes**: Modify staking reward rates
2. **Minimum Stake Changes**: Adjust minimum staking requirements
3. **Emergency Pause**: Pause contract operations

## 🔧 Installation & Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks CLI for deployment

### Local Development

1. **Clone and navigate to project**
   ```bash
   cd staking-pool
   ```

2. **Check contract syntax**
   ```bash
   clarinet check
   ```

3. **Run tests**
   ```bash
   clarinet test
   ```

4. **Start local development environment**
   ```bash
   clarinet integrate
   ```

### Deployment

1. **Deploy to testnet**
   ```bash
   clarinet deployment apply -p deployment.yaml --network testnet
   ```

2. **Verify deployment**
   ```bash
   clarinet deployment plan --network testnet
   ```

## 📖 Usage Examples

### Staking STX

```clarity
;; Stake 10 STX
(contract-call? .staking-pool stake u10000000)

;; Add 5 more STX to existing stake
(contract-call? .staking-pool add-stake u5000000)
```

### Claiming Rewards

```clarity
;; Claim rewards without unstaking
(contract-call? .staking-pool claim-rewards)

;; Check pending rewards
(contract-call? .staking-pool get-pending-rewards tx-sender)
```

### Governance Participation

```clarity
;; Create proposal to change reward rate to 15 (1.5%)
(contract-call? .governance create-proposal 
  u1 u15 "Increase reward rate to 1.5% per 1000 blocks")

;; Vote on proposal #1 (support)
(contract-call? .governance vote u1 true)
```

## 🔒 Security Features

### Input Validation
- All amounts validated for non-zero values
- Minimum stake requirements enforced
- Maximum reward rate limits

### Access Controls
- Owner-only administrative functions
- Staker-only voting rights
- Emergency pause mechanisms

### Economic Security
- Reward calculations prevent overflow
- Contract balance checks before transfers
- Emergency unstaking preserves principal

## 📊 Contract Statistics

The contract provides comprehensive monitoring through read-only functions:

- **Total Staked**: Sum of all staked STX
- **Contract Balance**: Available STX for rewards
- **Active Stakers**: Number of current stakers
- **Reward Rate**: Current percentage rate
- **Contract Status**: Active/paused state

## 🐛 Bug Fixes from Phase 1

1. **Integer Division Bug**: 
   - **Issue**: `(/ (* amount duration REWARD-RATE) u1000)` resulted in zero rewards for small amounts
   - **Fix**: Enhanced precision calculation with minimum reward guarantee

2. **Missing Balance Checks**:
   - **Issue**: Contract could attempt transfers without sufficient balance
   - **Fix**: Added balance validation before all transfers

3. **No Unstaking Without Claims**:
   - **Issue**: Users had to claim rewards to unstake
   - **Fix**: Added separate `emergency-unstake` and enhanced `unstake` functions

## 📋 Error Codes

| Code | Description |
|------|-------------|
| u400 | Invalid amount or parameter |
| u401 | Not authorized |
| u402 | Insufficient balance |
| u403 | Transfer failed |
| u404 | No stake found |
| u405 | Already staking/voted |
| u406 | Proposal expired |
| u407 | Contract paused |
| u408 | Below minimum stake |
| u409 | No rewards available |
| u410 | Invalid reward amount |

## 🔮 Future Enhancements

- **Multi-token Support**: Stake different SIP-010 tokens
- **Penalty System**: Slashing for early unstaking
- **Delegation**: Allow others to stake on behalf
- **Compound Rewards**: Auto-restake claimed rewards
- **Time-locked Staking**: Higher rewards for longer commitments

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📞 Support

- **Documentation**: Check this README and inline comments
- **Issues**: Open GitHub issues for bugs or feature requests
- **Community**: Join the Stacks community Discord

