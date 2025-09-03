// ERC-8004 Trustless Agents Web Interface
// Connects to deployed contracts on multiple testnets

class TrustlessAgentsApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.selectedNetwork = null;
        this.contracts = {};
        
        // Network configurations
        this.networks = {
            sepolia: {
                name: "Ethereum Sepolia",
                chainId: 11155111,
                rpcUrl: "https://sepolia.infura.io/v3/",
                explorer: "https://sepolia.etherscan.io",
                contracts: {
                    // Will be populated after deployment
                    identityRegistry: "",
                    reputationRegistry: "",
                    validationRegistry: ""
                }
            },
            base_sepolia: {
                name: "Base Sepolia",
                chainId: 84532,
                rpcUrl: "https://sepolia.base.org",
                explorer: "https://sepolia.basescan.org",
                contracts: {
                    identityRegistry: "",
                    reputationRegistry: "",
                    validationRegistry: ""
                }
            },
            arbitrum_sepolia: {
                name: "Arbitrum Sepolia",
                chainId: 421614,
                rpcUrl: "https://sepolia-rollup.arbitrum.io/rpc",
                explorer: "https://sepolia.arbiscan.io",
                contracts: {
                    identityRegistry: "",
                    reputationRegistry: "",
                    validationRegistry: ""
                }
            },
            optimism_sepolia: {
                name: "Optimism Sepolia",
                chainId: 11155420,
                rpcUrl: "https://sepolia.optimism.io",
                explorer: "https://sepolia-optimistic.etherscan.io",
                contracts: {
                    identityRegistry: "",
                    reputationRegistry: "",
                    validationRegistry: ""
                }
            }
        };

        // Contract ABI (simplified for registration)
        this.identityRegistryABI = [
            "function newAgent(string memory agentDomain, address agentAddress) external returns (uint256)",
            "function getAgent(uint256 agentId) external view returns (uint256, string memory, address)",
            "function resolveByDomain(string memory agentDomain) external view returns (uint256, string memory, address)",
            "function resolveByAddress(address agentAddress) external view returns (uint256, string memory, address)",
            "event AgentRegistered(uint256 indexed agentId, string agentDomain, address indexed agentAddress)"
        ];

        this.init();
    }

    async init() {
        this.setupEventListeners();
        this.renderNetworkSelector();
        await this.checkWalletConnection();
    }

    setupEventListeners() {
        document.getElementById('connectWallet').addEventListener('click', () => this.connectWallet());
        document.getElementById('registrationForm').addEventListener('submit', (e) => this.handleRegistration(e));
        
        // Auto-fill agent address with connected wallet
        document.getElementById('agentAddress').addEventListener('focus', () => {
            if (this.signer && !document.getElementById('agentAddress').value) {
                this.signer.getAddress().then(address => {
                    document.getElementById('agentAddress').value = address;
                });
            }
        });
    }

    renderNetworkSelector() {
        const selector = document.getElementById('networkSelector');
        selector.innerHTML = '';

        Object.entries(this.networks).forEach(([key, network]) => {
            const option = document.createElement('div');
            option.className = 'network-option';
            option.dataset.network = key;
            
            option.innerHTML = `
                <div class="network-name">${network.name}</div>
                <div class="network-chain">Chain ID: ${network.chainId}</div>
            `;
            
            option.addEventListener('click', () => this.selectNetwork(key));
            selector.appendChild(option);
        });
    }

    selectNetwork(networkKey) {
        // Remove previous selection
        document.querySelectorAll('.network-option').forEach(option => {
            option.classList.remove('selected');
        });
        
        // Select new network
        document.querySelector(`[data-network="${networkKey}"]`).classList.add('selected');
        this.selectedNetwork = networkKey;
        
        // Update contract info display
        this.updateContractInfo();
    }

    updateContractInfo() {
        const contractsInfo = document.getElementById('contractsInfo');
        const contractAddresses = document.getElementById('contractAddresses');
        
        if (!this.selectedNetwork) {
            contractsInfo.style.display = 'none';
            return;
        }

        const network = this.networks[this.selectedNetwork];
        contractsInfo.style.display = 'block';
        
        contractAddresses.innerHTML = `
            <div style="margin-bottom: 15px;">
                <strong>${network.name}</strong>
            </div>
            <div style="margin-bottom: 10px;">
                <strong>Identity Registry:</strong>
                <div class="contract-address">${network.contracts.identityRegistry || 'Not deployed yet'}</div>
            </div>
            <div style="margin-bottom: 10px;">
                <strong>Reputation Registry:</strong>
                <div class="contract-address">${network.contracts.reputationRegistry || 'Not deployed yet'}</div>
            </div>
            <div style="margin-bottom: 10px;">
                <strong>Validation Registry:</strong>
                <div class="contract-address">${network.contracts.validationRegistry || 'Not deployed yet'}</div>
            </div>
        `;
    }

    async checkWalletConnection() {
        if (typeof window.ethereum !== 'undefined') {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                if (accounts.length > 0) {
                    await this.connectWallet();
                }
            } catch (error) {
                console.error('Error checking wallet connection:', error);
            }
        }
    }

    async connectWallet() {
        try {
            if (typeof window.ethereum === 'undefined') {
                this.showStatus('Please install MetaMask or another Web3 wallet', 'error');
                return;
            }

            // Request account access
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            
            // Create provider and signer
            this.provider = new ethers.providers.Web3Provider(window.ethereum);
            this.signer = this.provider.getSigner();
            
            const address = await this.signer.getAddress();
            const network = await this.provider.getNetwork();
            
            // Update UI
            const walletInfo = document.getElementById('walletInfo');
            walletInfo.classList.add('connected');
            document.getElementById('walletStatus').innerHTML = `
                <i class="fas fa-check-circle" style="color: #10b981;"></i>
                Connected: ${address.substring(0, 6)}...${address.substring(38)}
                <br><small>Network: ${network.name} (${network.chainId})</small>
            `;
            document.getElementById('connectWallet').style.display = 'none';
            document.getElementById('registrationForm').style.display = 'block';
            
            // Auto-fill agent address
            document.getElementById('agentAddress').value = address;
            
        } catch (error) {
            console.error('Error connecting wallet:', error);
            this.showStatus('Failed to connect wallet: ' + error.message, 'error');
        }
    }

    async handleRegistration(event) {
        event.preventDefault();
        
        if (!this.selectedNetwork) {
            this.showStatus('Please select a network', 'error');
            return;
        }
        
        if (!this.signer) {
            this.showStatus('Please connect your wallet first', 'error');
            return;
        }

        const agentDomain = document.getElementById('agentDomain').value.trim();
        const agentAddress = document.getElementById('agentAddress').value.trim();
        
        if (!agentDomain || !agentAddress) {
            this.showStatus('Please fill in all fields', 'error');
            return;
        }

        // Validate Ethereum address
        if (!ethers.utils.isAddress(agentAddress)) {
            this.showStatus('Invalid Ethereum address', 'error');
            return;
        }

        try {
            await this.registerAgent(agentDomain, agentAddress);
        } catch (error) {
            console.error('Registration error:', error);
            this.showStatus('Registration failed: ' + error.message, 'error');
        }
    }

    async registerAgent(agentDomain, agentAddress) {
        const network = this.networks[this.selectedNetwork];
        
        if (!network.contracts.identityRegistry) {
            this.showStatus('Contracts not deployed on this network yet', 'error');
            return;
        }

        this.showStatus('Registering agent...', 'loading');
        
        try {
            // Check if we need to switch networks
            const currentNetwork = await this.provider.getNetwork();
            if (currentNetwork.chainId !== network.chainId) {
                await this.switchNetwork(network);
            }
            
            // Create contract instance
            const contract = new ethers.Contract(
                network.contracts.identityRegistry,
                this.identityRegistryABI,
                this.signer
            );
            
            // Estimate gas
            const gasEstimate = await contract.estimateGas.newAgent(agentDomain, agentAddress);
            
            // Send transaction
            const tx = await contract.newAgent(agentDomain, agentAddress, {
                gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
            });
            
            this.showStatus(`Transaction sent: ${tx.hash}`, 'loading');
            
            // Wait for confirmation
            const receipt = await tx.wait();
            
            // Parse events to get agent ID
            const event = receipt.events?.find(e => e.event === 'AgentRegistered');
            const agentId = event?.args?.agentId?.toString();
            
            this.showStatus(`
                <i class="fas fa-check-circle"></i> 
                Agent registered successfully!<br>
                <strong>Agent ID:</strong> ${agentId}<br>
                <strong>Transaction:</strong> 
                <a href="${network.explorer}/tx/${tx.hash}" target="_blank" style="color: inherit;">
                    ${tx.hash.substring(0, 10)}...
                </a>
            `, 'success');
            
        } catch (error) {
            if (error.code === 4001) {
                this.showStatus('Transaction cancelled by user', 'error');
            } else if (error.code === -32603) {
                this.showStatus('Transaction failed: ' + (error.data?.message || error.message), 'error');
            } else {
                this.showStatus('Registration failed: ' + error.message, 'error');
            }
        }
    }

    async switchNetwork(network) {
        try {
            await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: ethers.utils.hexValue(network.chainId) }],
            });
        } catch (switchError) {
            // This error code indicates that the chain has not been added to MetaMask
            if (switchError.code === 4902) {
                try {
                    await window.ethereum.request({
                        method: 'wallet_addEthereumChain',
                        params: [{
                            chainId: ethers.utils.hexValue(network.chainId),
                            chainName: network.name,
                            rpcUrls: [network.rpcUrl],
                            blockExplorerUrls: [network.explorer]
                        }],
                    });
                } catch (addError) {
                    throw new Error('Failed to add network to wallet');
                }
            } else {
                throw switchError;
            }
        }
    }

    showStatus(message, type) {
        const status = document.getElementById('status');
        status.className = `status ${type}`;
        status.innerHTML = message;
        status.style.display = 'block';
        
        // Auto-hide success messages after 10 seconds
        if (type === 'success') {
            setTimeout(() => {
                status.style.display = 'none';
            }, 10000);
        }
    }

    // Method to update contract addresses after deployment
    updateContractAddresses(networkKey, addresses) {
        if (this.networks[networkKey]) {
            this.networks[networkKey].contracts = addresses;
            if (this.selectedNetwork === networkKey) {
                this.updateContractInfo();
            }
        }
    }
}

// Initialize the app when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.trustlessAgentsApp = new TrustlessAgentsApp();
});

// Example of how to update contract addresses after deployment:
// window.trustlessAgentsApp.updateContractAddresses('sepolia', {
//     identityRegistry: '0x...',
//     reputationRegistry: '0x...',
//     validationRegistry: '0x...'
// });
