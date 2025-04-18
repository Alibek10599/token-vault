import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Input, Button, Divider, Typography, Spin, Alert } from 'antd';
import { useWallet } from '@solana/wallet-adapter-react';
import { PublicKey } from '@solana/web3.js';
import { getTokenAccount, initializeVault, depositToVault, withdrawFromVault } from '../utils/vaultOperations';

const { Text, Title } = Typography;

interface VaultManagerProps {
  programId: string;
  tokenMint: string;
}

const VaultManager: React.FC<VaultManagerProps> = ({ programId, tokenMint }) => {
  const { publicKey, connected } = useWallet();
  const [loading, setLoading] = useState(false);
  const [amount, setAmount] = useState('');
  const [vaultAddress, setVaultAddress] = useState<string | null>(null);
  const [vaultInfo, setVaultInfo] = useState<any | null>(null);
  const [userTokenAccount, setUserTokenAccount] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (connected && publicKey) {
      fetchUserTokenAccount();
      fetchVaultInfo();
    }
  }, [connected, publicKey]);

  const fetchUserTokenAccount = async () => {
    if (!publicKey) return;
    
    try {
      const tokenAccount = await getTokenAccount(publicKey.toString(), tokenMint);
      setUserTokenAccount(tokenAccount);
    } catch (err) {
      console.error('Error fetching token account:', err);
      setError('Could not find your token account. Make sure you have USDC tokens.');
    }
  };

  const fetchVaultInfo = async () => {
    try {
      // This is a placeholder - implement actual vault fetch logic
      setLoading(true);
      
      // Simulate API call
      setTimeout(() => {
        setVaultAddress('vault_address_placeholder');
        setVaultInfo({
          authority: 'authority_placeholder',
          balance: 1000,
          feePercentage: 1.0,
          withdrawalTimelock: 86400,
        });
        setLoading(false);
      }, 1000);
    } catch (err) {
      console.error('Error fetching vault info:', err);
      setError('Could not fetch vault information');
      setLoading(false);
    }
  };

  const handleCreateVault = async () => {
    if (!publicKey) return;
    
    try {
      setLoading(true);
      setError(null);
      
      // Call initialize vault function
      const newVaultAddress = await initializeVault(
        programId,
        tokenMint,
        publicKey.toString(),
        "My Token Vault",
        100, // 1% fee
        86400 // 1 day timelock
      );
      
      setVaultAddress(newVaultAddress);
      await fetchVaultInfo();
    } catch (err) {
      console.error('Error creating vault:', err);
      setError('Failed to create vault. Check the console for details.');
    } finally {
      setLoading(false);
    }
  };

  const depositTokens = async () => {
    if (!publicKey || !vaultAddress || !userTokenAccount || !amount) return;
    
    try {
      setLoading(true);
      setError(null);
      
      await depositToVault(
        programId,
        vaultAddress,
        userTokenAccount,
        parseFloat(amount)
      );
      
      setAmount('');
      await fetchVaultInfo();
    } catch (err) {
      console.error('Error depositing tokens:', err);
      setError('Failed to deposit tokens. Check the console for details.');
    } finally {
      setLoading(false);
    }
  };

  const withdrawTokens = async () => {
    if (!publicKey || !vaultAddress || !userTokenAccount || !amount || !isAuthority()) return;
    
    try {
      setLoading(true);
      setError(null);
      
      await withdrawFromVault(
        programId,
        vaultAddress,
        userTokenAccount,
        parseFloat(amount)
      );
      
      setAmount('');
      await fetchVaultInfo();
    } catch (err) {
      console.error('Error withdrawing tokens:', err);
      setError('Failed to withdraw tokens. Check the console for details.');
    } finally {
      setLoading(false);
    }
  };

  const isAuthority = () => {
    if (!publicKey || !vaultInfo) return false;
    return publicKey.toString() === vaultInfo.authority;
  };

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto' }}>
      {error && (
        <Alert
          message="Error"
          description={error}
          type="error"
          showIcon
          style={{ marginBottom: '16px' }}
          closable
          onClose={() => setError(null)}
        />
      )}

      {!connected ? (
        <Card>
          <Title level={4}>Connect your wallet to manage the token vault</Title>
        </Card>
      ) : (
        <>
          {!vaultAddress ? (
            <Card>
              <Title level={4}>Create a New Token Vault</Title>
              <Button
                type="primary"
                onClick={handleCreateVault}
                loading={loading}
                block
              >
                Create Vault
              </Button>
            </Card>
          ) : (
            <Card title="Manage Your Token Vault" loading={loading}>
              <div style={{ marginBottom: '16px' }}>
                <Text>Vault Address: {vaultAddress}</Text>
              </div>
              
              {vaultInfo && (
                <div style={{ marginBottom: '16px' }}>
                  <Text>Vault Balance: {vaultInfo.balance} USDC</Text>
                  <br />
                  <Text>Fee Percentage: {vaultInfo.feePercentage}%</Text>
                  <br />
                  <Text>Withdrawal Timelock: {vaultInfo.withdrawalTimelock / 3600} hours</Text>
                </div>
              )}

              <Row gutter={16}>
                <Col span={16}>
                  <Input
                    placeholder="Amount"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    suffix="USDC"
                    type="number"
                    min="0"
                  />
                </Col>
                <Col span={8}>
                  <Button
                    type="primary"
                    onClick={depositTokens}
                    loading={loading}
                    block
                    disabled={!amount || parseFloat(amount) <= 0 || !userTokenAccount}
                  >
                    Deposit
                  </Button>
                </Col>
              </Row>

              <Divider style={{ margin: '12px 0' }} />

              <Row gutter={16}>
                <Col span={16}>
                  <Input
                    placeholder="Amount"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    suffix="USDC"
                    type="number"
                    min="0"
                  />
                </Col>
                <Col span={8}>
                  <Button
                    onClick={withdrawTokens}
                    loading={loading}
                    block
                    danger
                    disabled={
                      !amount ||
                      parseFloat(amount) <= 0 ||
                      !isAuthority() ||
                      !userTokenAccount
                    }
                  >
                    Withdraw
                  </Button>
                </Col>
              </Row>

              {!isAuthority() && (
                <div style={{ marginTop: '12px' }}>
                  <Text type="warning">Only the vault authority can withdraw funds</Text>
                </div>
              )}
            </Card>
          )}
        </>
      )}
    </div>
  );
};

export default VaultManager;
