import React from 'react';
import { Layout, Typography} from 'antd';
import { WalletAdapterNetwork } from '@solana/wallet-adapter-base';
import {
  ConnectionProvider,
  WalletProvider,
} from '@solana/wallet-adapter-react';
import {
  PhantomWalletAdapter,
  SolflareWalletAdapter,
  TorusWalletAdapter,
} from '@solana/wallet-adapter-wallets';
import { WalletModalProvider, WalletMultiButton } from '@solana/wallet-adapter-react-ui';
import { clusterApiUrl } from '@solana/web3.js';
import VaultManager from './components/VaultManager';
import '@solana/wallet-adapter-react-ui/styles.css';

const { Header, Content, Footer } = Layout;
const { Title } = Typography;

// You can change this to mainnet, devnet, or testnet
const network = WalletAdapterNetwork.Devnet;

// Token mint address for USDC on devnet (replace with actual address for production)
const USDC_MINT = "Gh9ZwEmdLJ8DscKNTkTqPbNwLNNBjuSzaG9Vp2KGtKJr";

// Token vault program ID (replace with your deployed program ID)
const PROGRAM_ID = "TokenVaultProgramIDGoesHere11111111111111111";

const App: React.FC = () => {
  // The endpoint will depend on which cluster your app is using
  const endpoint = clusterApiUrl(network);

  // @solana/wallet-adapter-wallets includes all the wallets that support Wallet Standard
  const wallets = [
    new PhantomWalletAdapter(),
    new SolflareWalletAdapter({ network }),
    new TorusWalletAdapter(),
  ];

  return (
    <ConnectionProvider endpoint={endpoint}>
      <WalletProvider wallets={wallets} autoConnect>
        <WalletModalProvider>
          <Layout style={{ minHeight: '100vh' }}>
            <Header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 50px' }}>
              <Title level={3} style={{ color: 'white', margin: 0 }}>
                Token Vault App
              </Title>
              <WalletMultiButton />
            </Header>
            
            <Content style={{ padding: '50px' }}>
              <div style={{ background: '#fff', padding: 24, borderRadius: 4 }}>
                <Title level={2}>Token Vault Management</Title>
                <p>
                  This application allows you to create and manage token vaults for storing and
                  securing your SPL tokens with customizable fee and withdrawal parameters.
                </p>
                
                <VaultManager 
                  programId={PROGRAM_ID}
                  tokenMint={USDC_MINT}
                />
              </div>
            </Content>
            
            <Footer style={{ textAlign: 'center' }}>
              Token Vault App ©{new Date().getFullYear()} Created with Solana and React
            </Footer>
          </Layout>
        </WalletModalProvider>
      </WalletProvider>
    </ConnectionProvider>
  );
};

export default App;
