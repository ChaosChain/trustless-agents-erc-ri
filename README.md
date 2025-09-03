# ERC-8004 Trustless Agents Web Interface

A modern, responsive web interface for registering agents on the ERC-8004 Trustless Agents protocol.

## Features

- **Multi-Network Support**: Ethereum, Base, Arbitrum, and Optimism Sepolia testnets
- **Wallet Integration**: MetaMask and other Web3 wallets
- **Real-Time Registration**: Direct interaction with deployed contracts
- **Network Switching**: Automatic network detection and switching
- **Mobile Responsive**: Works on desktop and mobile devices
- **Transaction Tracking**: Links to block explorers for verification

## Quick Start

### Local Development

1. **Serve the files**:
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx serve
   
   # Using PHP
   php -S localhost:8000
   ```

2. **Open in browser**: `http://localhost:8000`

### Update Contract Addresses

After deploying contracts, update `config.js` with the deployed addresses:

```javascript
const CONTRACT_ADDRESSES = {
    sepolia: {
        identityRegistry: "0x...",
        reputationRegistry: "0x...",
        validationRegistry: "0x..."
    },
    // ... other networks
};
```

Or use the automated script:
```bash
node ../scripts/update-web-config.js
```

## 📱 Usage

1. **Connect Wallet**: Click "Connect Wallet" and approve the connection
2. **Fill Agent Details**:
   - **Agent Domain**: Your domain where the agent card is hosted
   - **Agent Address**: Ethereum address that will control the agent
3. **Select Network**: Choose which testnet to deploy on
4. **Register**: Submit the transaction and wait for confirmation

## 🔧 Technical Details

### Dependencies

- **ethers.js v5**: Web3 library for blockchain interaction
- **Font Awesome**: Icons for the interface
- **Pure CSS**: No framework dependencies for maximum compatibility

### Contract Integration

The interface interacts with three main contracts:

- **IdentityRegistry**: Agent registration and resolution
- **ReputationRegistry**: Feedback authorization
- **ValidationRegistry**: Work validation requests

### Network Configuration

Supports four Sepolia testnets with automatic RPC configuration:

| Network | Chain ID | Explorer |
|---------|----------|----------|
| Ethereum Sepolia | 11155111 | sepolia.etherscan.io |
| Base Sepolia | 84532 | sepolia.basescan.org |
| Arbitrum Sepolia | 421614 | sepolia.arbiscan.io |
| Optimism Sepolia | 11155420 | sepolia-optimistic.etherscan.io |

## Customization

### Styling

The interface uses CSS custom properties for easy theming:

```css
:root {
    --primary-color: #4f46e5;
    --secondary-color: #7c3aed;
    --success-color: #10b981;
    --error-color: #ef4444;
}
```

### Adding Networks

To add new networks, update the `networks` object in `app.js`:

```javascript
this.networks = {
    // ... existing networks
    new_network: {
        name: "New Network",
        chainId: 12345,
        rpcUrl: "https://rpc.newnetwork.com",
        explorer: "https://explorer.newnetwork.com",
        contracts: {
            identityRegistry: "",
            reputationRegistry: "",
            validationRegistry: ""
        }
    }
};
```

## Security

- **Client-Side Only**: No server-side components or data storage
- **Wallet Security**: Uses standard Web3 wallet security practices
- **Input Validation**: Validates addresses and domains before submission
- **Network Verification**: Confirms network before transactions

## Deployment

### Static Hosting

Deploy to any static hosting service:

```bash
# GitHub Pages
git subtree push --prefix web origin gh-pages

# Netlify
netlify deploy --dir=web --prod

# Vercel
vercel --prod web/

# IPFS (decentralized)
ipfs add -r web/
```

### Custom Domain

For production deployment:

1. Update the GitHub repository URL in the footer
2. Configure your domain's DNS
3. Enable HTTPS (most hosts do this automatically)
4. Update any hardcoded URLs to use your domain

## Troubleshooting

### Common Issues

1. **"Please install MetaMask"**: User needs a Web3 wallet
2. **"Network not supported"**: Wallet needs to add the network
3. **"Contracts not deployed"**: Update `config.js` with addresses
4. **"Transaction failed"**: Check domain isn't already registered

### Debug Mode

Enable console logging by adding to `app.js`:

```javascript
const DEBUG = true;
if (DEBUG) console.log('Debug info:', data);
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple networks
5. Submit a pull request

## License

MIT License - see the main repository for details.

---

**Need help?** Open an issue on the [main repository](https://github.com/ChaosChain/trustless-agents-erc-ri) or join the discussion on [Ethereum Magicians](https://ethereum-magicians.org/t/erc-8004-trustless-agents/25098).
