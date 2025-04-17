use anchor_client::{
    solana_sdk::{
        commitment_config::CommitmentConfig,
        pubkey::Pubkey,
        signature::{Keypair, Signer},
        system_program,
    },
    Client, Cluster, Program,
};
use anchor_lang::prelude::*;
use anchor_spl::token::{self, TokenAccount, Token};
use anyhow::{anyhow, Result};
use std::rc::Rc;
use std::str::FromStr;

/// TokenVaultClient provides a Rust interface to interact with the token vault program
pub struct TokenVaultClient {
    program: Program,
    vault_address: Option<Pubkey>,
}

impl TokenVaultClient {
    /// Create a new client instance
    pub fn new(
        cluster: Cluster,
        payer: Keypair,
        program_id: Pubkey,
    ) -> Result<Self> {
        let client = Client::new_with_options(
            cluster,
            Rc::new(payer),
            CommitmentConfig::confirmed(),
        );

        let program = client.program(program_id);

        Ok(Self {
            program,
            vault_address: None,
        })
    }

    /// Set the vault address to interact with
    pub fn with_vault(&mut self, vault_address: Pubkey) -> &mut Self {
        self.vault_address = Some(vault_address);
        self
    }

    /// Initialize a new vault
    pub fn initialize_vault(
        &self,
        authority: &Keypair,
        token_mint: Pubkey,
        vault_name: &str,
        fee_percentage: u16,
        withdrawal_timelock: i64,
        withdrawal_limit: u64,
    ) -> Result<Pubkey> {
        // Derive vault address
        let (vault_address, _) = Pubkey::find_program_address(
            &[
                b"vault".as_ref(),
                authority.pubkey().as_ref(),
                token_mint.as_ref(),
                vault_name.as_bytes(),
            ],
            &self.program.id(),
        );

        // Derive token account address that will hold the tokens
        let (vault_token_account, _) = Pubkey::find_program_address(
            &[b"vault_token_account".as_ref(), vault_address.as_ref()],
            &self.program.id(),
        );

        println!("Creating vault with address: {}", vault_address);

        // Build and send transaction
        let signature = self
            .program
            .request()
            .accounts(token_vault::accounts::InitializeVault {
                authority: authority.pubkey(),
                vault: vault_address,
                vault_token_account,
                token_mint,
                token_program: token::ID,
                system_program: system_program::ID,
                rent: anchor_client::solana_sdk::sysvar::rent::ID,
            })
            .args(token_vault::instruction::InitializeVault {
                name: vault_name.to_string(),
                fee_percentage,
                withdrawal_timelock,
                withdrawal_limit,
            })
            .signer(authority)
            .send()?;

        println!("Vault created successfully! Signature: {}", signature);
        Ok(vault_address)
    }

    /// Deposit tokens into the vault
    pub fn deposit(
        &self,
        depositor: &Keypair,
        amount: u64,
    ) -> Result<()> {
        let vault = self.vault_address.ok_or_else(|| anyhow!("Vault address not set"))?;

        // Derive the vault token account address
        let (vault_token_account, _) = Pubkey::find_program_address(
            &[b"vault_token_account".as_ref(), vault.as_ref()],
            &self.program.id(),
        );

        // Get vault data to determine the token mint
        let vault_data: token_vault::state::Vault = self.program.account(vault)?;
        let token_mint = vault_data.token_mint;

        // Derive the depositor's token account
        let depositor_token_account = anchor_client::solana_sdk::associated_token::get_associated_token_address(
            &depositor.pubkey(),
            &token_mint,
        );

        println!("Depositing {} tokens to vault {}", amount, vault);

        // Build and send transaction
        let signature = self
            .program
            .request()
            .accounts(token_vault::accounts::Deposit {
                depositor: depositor.pubkey(),
                vault,
                vault_token_account,
                depositor_token_account,
                token_program: token::ID,
            })
            .args(token_vault::instruction::Deposit {
                amount,
            })
            .signer(depositor)
            .send()?;

        println!("Deposit successful! Signature: {}", signature);
        Ok(())
    }

    /// Withdraw tokens from the vault
    pub fn withdraw(
        &self,
        withdrawer: &Keypair,
        amount: u64,
    ) -> Result<()> {
        let vault = self.vault_address.ok_or_else(|| anyhow!("Vault address not set"))?;

        // Derive the vault token account address
        let (vault_token_account, _) = Pubkey::find_program_address(
            &[b"vault_token_account".as_ref(), vault.as_ref()],
            &self.program.id(),
        );

        // Get vault data to determine the token mint and authority
        let vault_data: token_vault::state::Vault = self.program.account(vault)?;
        let token_mint = vault_data.token_mint;
        let vault_authority = vault_data.authority;

        // Derive the depositor's token account
        let withdrawer_token_account = anchor_client::solana_sdk::associated_token::get_associated_token_address(
            &withdrawer.pubkey(),
            &token_mint,
        );

        // Derive the fee collector token account
        let fee_collector_token_account = anchor_client::solana_sdk::associated_token::get_associated_token_address(
            &vault_data.fee_collector,
            &token_mint,
        );

        println!("Withdrawing {} tokens from vault {}", amount, vault);

        // Build and send transaction
        let signature = self
            .program
            .request()
            .accounts(token_vault::accounts::Withdraw {
                withdrawer: withdrawer.pubkey(),
                vault,
                vault_token_account,
                withdrawer_token_account,
                fee_collector_token_account,
                token_program: token::ID,
            })
            .args(token_vault::instruction::Withdraw {
                amount,
            })
            .signer(withdrawer)
            .send()?;

        println!("Withdrawal successful! Signature: {}", signature);
        Ok(())
    }

    /// Get vault information
    pub fn get_vault_info(&self) -> Result<token_vault::state::Vault> {
        let vault = self.vault_address.ok_or_else(|| anyhow!("Vault address not set"))?;
        let vault_data: token_vault::state::Vault = self.program.account(vault)?;
        Ok(vault_data)
    }
}

/// Namespace for mock token vault program structures (replace with actual program structures)
pub mod token_vault {
    use anchor_lang::prelude::*;
    
    pub mod state {
        use super::*;
        
        #[account]
        pub struct Vault {
            pub authority: Pubkey,
            pub token_mint: Pubkey,
            pub fee_collector: Pubkey,
            pub fee_percentage: u16,
            pub withdrawal_timelock: i64,
            pub withdrawal_limit: u64,
            pub total_deposited: u64,
            pub name: String,
            pub bump: u8,
        }
    }

    pub mod accounts {
        use super::*;
        
        #[derive(Accounts)]
        pub struct InitializeVault<'info> {
            pub authority: Signer<'info>,
            #[account(mut)]
            pub vault: AccountInfo<'info>,
            #[account(mut)]
            pub vault_token_account: AccountInfo<'info>,
            pub token_mint: AccountInfo<'info>,
            pub token_program: AccountInfo<'info>,
            pub system_program: AccountInfo<'info>,
            pub rent: AccountInfo<'info>,
        }

        #[derive(Accounts)]
        pub struct Deposit<'info> {
            pub depositor: Signer<'info>,
            #[account(mut)]
            pub vault: AccountInfo<'info>,
            #[account(mut)]
            pub vault_token_account: AccountInfo<'info>,
            #[account(mut)]
            pub depositor_token_account: AccountInfo<'info>,
            pub token_program: AccountInfo<'info>,
        }

        #[derive(Accounts)]
        pub struct Withdraw<'info> {
            pub withdrawer: Signer<'info>,
            #[account(mut)]
            pub vault: AccountInfo<'info>,
            #[account(mut)]
            pub vault_token_account: AccountInfo<'info>,
            #[account(mut)]
            pub withdrawer_token_account: AccountInfo<'info>,
            #[account(mut)]
            pub fee_collector_token_account: AccountInfo<'info>,
            pub token_program: AccountInfo<'info>,
        }
    }

    pub mod instruction {
        use super::*;
        
        #[derive(AnchorSerialize, AnchorDeserialize)]
        pub struct InitializeVault {
            pub name: String,
            pub fee_percentage: u16,
            pub withdrawal_timelock: i64,
            pub withdrawal_limit: u64,
        }

        #[derive(AnchorSerialize, AnchorDeserialize)]
        pub struct Deposit {
            pub amount: u64,
        }

        #[derive(AnchorSerialize, AnchorDeserialize)]
        pub struct Withdraw {
            pub amount: u64,
        }
    }
}

// Utility functions for loading keypair from file
pub mod utils {
    use anchor_client::solana_sdk::signature::{Keypair, read_keypair_file};
    use anyhow::Result;
    
    pub fn load_keypair(keypair_path: &str) -> Result<Keypair> {
        let expanded_path = shellexpand::tilde(keypair_path);
        let keypair = read_keypair_file(expanded_path.as_ref())?;
        Ok(keypair)
    }
}
