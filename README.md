# Token Vault - Blockchain Application

A secure multi-chain token vault system built with Rust and Solidity.

## Overview

This project demonstrates a secure, production-ready token vault implementation across multiple blockchain ecosystems:

- **Solana Program (Rust)**: A secure token vault using Anchor framework
- **Ethereum Smart Contract (Solidity)**: A compatible vault implementation for EVM chains
- **Rust Client**: Integration tools to interact with the Solana program
- **React Frontend**: Cross-chain UI for interacting with both implementations

The vault system provides secure token custody with role-based access control, time-locked withdrawals, fee mechanisms, and proper security considerations.

## Architecture

![Architecture Diagram](https://via.placeholder.com/800x400?text=Vault+Architecture+Diagram)

### Core Components

1. **Solana Token Vault Program**

   - Built with Anchor framework
   - Program-derived accounts (PDAs) for secure token custody
   - Comprehensive event logging and error handling
   - Security-focused architecture with proper account validation

2. **Ethereum Token Vault Contract**

   - ERC20 compatible token vault
   - Role-based access control system
   - Time-locked withdrawals and limits
   - Gas-optimized fee mechanism
   - Emergency pause functionality

3. **Rust Client Integration**

   - Native Rust client for programmatic interaction with Solana program
   - Transaction building and submission
   - Account state management
   - Error handling and recovery mechanisms

4. **React Frontend**
   - Responsive web interface for both implementations
   - Wallet integration (Phantom, Solflare, MetaMask)
   - Real-time transaction status and account data
   - User-friendly token deposit and withdrawal flow

## Security Features

- **Ownership Model**: Clear authority controls with secure transfer mechanisms
- **Time-locked Withdrawals**: Cooldown periods between withdrawals
- **Withdrawal Limits**: Configurable maximum withdrawal amounts
- **Version Tracking**: Security version tracking for upgrades
- **Role Separation**: Multi-role access control for different operations
- **Comprehensive Testing**: Thorough test coverage for all critical paths
- **Fee Mechanisms**: Configurable fee structure with maximum caps

## Local Development

### Prerequisites

- Rust 1.67+ with `cargo`
- Node.js 16+ with `npm`
- Solana CLI tools
- Anchor framework 0.26+
- Foundry for Ethereum development

### Setup

1. Install Rust and Solana CLI:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   sh -c "$(curl -sSfL https://release.solana.com/v1.16.0/install)"
   ```

2. Install Anchor:

   ```bash
   cargo install --git https://github.com/coral-xyz/anchor avm --locked
   avm install latest
   avm use latest
   ```

3. Install Foundry (for Ethereum development):

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

4. Clone and build the project:
   ```bash
   git clone https://github.com/yourusername/token-vault.git
   cd token-vault
   cargo build
   ```

### Running Tests

#### Solana Program Tests

```bash
anchor test
```

#### Ethereum Contract Tests

```bash
forge test -vvv
```

#### Integration Tests

```bash
cargo test --package token-vault-client
```

### Deploying to Devnet

1. Deploy Solana program:

   ```bash
   anchor deploy --provider.cluster devnet
   ```

2. Deploy Ethereum contract:
   ```bash
   forge create --rpc-url https://rpc.ankr.com/eth_goerli --private-key $PRIVATE_KEY src/TokenVault.sol:TokenVault
   ```

### Running the Frontend

```bash
cd frontend
npm install
npm start
```

## API Reference

### Solana Program Instructions

- `initialize_vault`: Create a new token vault
- `deposit`: Deposit tokens into the vault
- `withdraw`: Withdraw tokens from the vault (authority only)
- `update_authority`: Transfer vault authority to a new address

### Ethereum Contract Functions

- `deposit(uint256 amount)`: Deposit tokens
- `withdraw(uint256 amount)`: Withdraw tokens with timelock enforcement
- `emergencyWithdraw(uint256 amount)`: Emergency withdrawal (owner only)
- Multiple administrative functions for updating fees, authorities, and limits

## Security Considerations

This project implements several security best practices:

1. **Access Control**: Clear separation of roles with proper authorization checks
2. **Reentrancy Protection**: Guards against reentrant attacks
3. **Input Validation**: Comprehensive validation of all inputs
4. **Error Handling**: Proper error propagation and recovery
5. **Rate Limiting**: Time-based withdrawal restrictions
6. **Audit Logging**: Event emission for all critical operations

## Advanced Features

### Cross-Chain Compatibility

The dual implementation allows for a consistent user experience across both Solana and Ethereum ecosystems, with a unified data model and similar security properties.

### Upgrade Paths

Both implementations include version tracking to support future upgrades while maintaining security:

- Solana: PDA-based upgrade mechanism
- Ethereum: Proxy pattern support for contract upgrades

### Governance Integration

The contracts are designed with governance integration in mind:

- Multi-signature support
- Timelock controls
- Operator roles for distributed administration

## Performance Optimizations

- **Ethereum**: Gas-optimized storage patterns and controlled state access
- **Solana**: Efficient account validation and computation minimization
- **Frontend**: Optimistic UI updates with confirmation reconciliation

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
