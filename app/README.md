# Token Vault Client

A Rust client library and application for interacting with the Token Vault Solana program. This client allows you to:

- Initialize new token vaults
- Deposit tokens into vaults
- Withdraw tokens from vaults
- Retrieve vault information

## Prerequisites

- Rust and Cargo installed
- Solana CLI tools installed
- A Solana wallet with funds for paying transaction fees

## Configuration

Before building and running the client, update the program ID and other configuration parameters in the `main.rs` file:

```rust
// Parse program ID
let program_id = Pubkey::from_str("YourProgramIdHere")?;

// For initialization
let token_mint = Pubkey::from_str("YourTokenMintAddressHere")?;
```

## Building

```bash
cargo build
```

## Running

```bash
cargo run --bin main
```

## Library Usage

### Initializing a Client

```rust
use token_vault_client::{TokenVaultClient, utils};

// Load keypair from file
let payer = utils::load_keypair("~/.config/solana/id.json")?;

// Parse program ID
let program_id = Pubkey::from_str("YourProgramIdHere")?;

// Connect to Solana cluster
let cluster = Cluster::Devnet;

// Create token vault client
let mut client = TokenVaultClient::new(
    cluster, 
    payer,
    program_id,
)?;
```

### Creating a New Vault

```rust
let vault_address = client.initialize_vault(
    &authority,
    token_mint,
    "My Token Vault",
    100, // 1% fee (in basis points)
    86400, // 1 day timelock (in seconds)
    1000_000_000, // Withdrawal limit
)?;

// Set the vault address for future operations
client.with_vault(vault_address);
```

### Depositing Tokens

```rust
client.deposit(
    &depositor_keypair,
    1000_000_000, // Amount to deposit
)?;
```

### Withdrawing Tokens

```rust
client.withdraw(
    &withdrawer_keypair,
    500_000_000, // Amount to withdraw
)?;
```

### Getting Vault Information

```rust
let vault_info = client.get_vault_info()?;
println!("Vault Info:");
println!("  Authority: {}", vault_info.authority);
println!("  Token Mint: {}", vault_info.token_mint);
println!("  Fee Percentage: {}", vault_info.fee_percentage);
println!("  Total Deposited: {}", vault_info.total_deposited);
```

## Error Handling

The client uses the `anyhow` crate for error handling. All public functions return `Result<T, anyhow::Error>` which allows for easy error propagation and handling.

## Integration with a Custom Program

The client code in this repository is designed to work with the Token Vault program. If you've modified the program's account structures or instruction data, you'll need to update the corresponding structures in the `token_vault` module in `lib.rs`.
