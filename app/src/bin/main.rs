use anchor_client::{
    solana_sdk::{
        pubkey::Pubkey,
        signature::Keypair,
    },
    Cluster,
};
use anyhow::Result;
use std::str::FromStr;
use token_vault_client::{TokenVaultClient, utils};

#[tokio::main]
async fn main() -> Result<()> {
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
    
    // Example: Initialize a new vault
    let token_mint = Pubkey::from_str("YourTokenMintAddressHere")?;
    let authority = utils::load_keypair("~/.config/solana/id.json")?;
    
    let vault_address = client.initialize_vault(
        &authority,
        token_mint,
        "My Token Vault",
        100, // 1% fee (in basis points)
        86400, // 1 day timelock (in seconds)
        1000_000_000, // Withdrawal limit (adjust decimal places based on token decimals)
    )?;
    
    println!("Vault initialized with address: {}", vault_address);
    
    // Set the vault address for future operations
    client.with_vault(vault_address);
    
    // Example: Deposit tokens
    client.deposit(
        &authority,
        1000_000_000, // Amount to deposit (adjust decimal places based on token decimals)
    )?;
    
    // Example: Withdraw tokens
    client.withdraw(
        &authority,
        500_000_000, // Amount to withdraw (adjust decimal places based on token decimals)
    )?;
    
    // Example: Get vault information
    let vault_info = client.get_vault_info()?;
    println!("Vault Info:");
    println!("  Authority: {}", vault_info.authority);
    println!("  Token Mint: {}", vault_info.token_mint);
    println!("  Fee Percentage: {}", vault_info.fee_percentage);
    println!("  Total Deposited: {}", vault_info.total_deposited);
    
    Ok(())
}
