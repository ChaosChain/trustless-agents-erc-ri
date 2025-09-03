// ERC-8004 Trustless Agents Web Interface
// Connects to deployed contracts on multiple testnets

class TrustlessAgentsApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.selectedNetwork = null;
        this.contracts = {};
        
        // Network configurations - contracts will be loaded from config.js
        this.networks = {
            sepolia: {
                name: "Ethereum Sepolia",
                chainId: 11155111,
                rpcUrl: "https://ethereum-sepolia-rpc.publicnode.com",
                explorer: "https://sepolia.etherscan.io",
                contracts: {}
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

                 // Contract ABI (correct return types matching AgentInfo struct)
         this.identityRegistryABI = [
             "function newAgent(string memory agentDomain, address agentAddress) external returns (uint256)",
             "function getAgent(uint256 agentId) external view returns (tuple(uint256 agentId, string agentDomain, address agentAddress))",
             "function resolveByDomain(string memory agentDomain) external view returns (tuple(uint256 agentId, string agentDomain, address agentAddress))",
             "function resolveByAddress(address agentAddress) external view returns (tuple(uint256 agentId, string agentDomain, address agentAddress))",
             "event AgentRegistered(uint256 indexed agentId, string agentDomain, address indexed agentAddress)"
         ];

        this.loadContractAddresses();
        this.init();
    }

    loadContractAddresses() {
        // Load contract addresses from config.js
        if (window.CONTRACT_ADDRESSES) {
            console.log('📋 Loading contract addresses from config...');
            Object.entries(window.CONTRACT_ADDRESSES).forEach(([networkKey, addresses]) => {
                if (this.networks[networkKey]) {
                    this.networks[networkKey].contracts = addresses;
                    console.log(`✅ Loaded contracts for ${networkKey}:`, addresses);
                }
            });
        } else {
            console.warn('⚠️ CONTRACT_ADDRESSES not found in window object');
        }
    }

    async init() {
        this.setupEventListeners();
        this.renderNetworkSelector();
        await this.checkWalletConnection();
    }

         setupEventListeners() {
         document.getElementById('connectWallet').addEventListener('click', () => this.connectWallet());
         document.getElementById('registrationForm').addEventListener('submit', (e) => this.handleRegistration(e));
         document.getElementById('lookupBtn').addEventListener('click', () => this.handleLookup());
         
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
            // Check if ethers is available
            if (typeof ethers === 'undefined') {
                this.showStatus('Web3 libraries not loaded. Please refresh the page.', 'error');
                return;
            }

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
             document.getElementById('lookupSection').style.display = 'block';
             
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
             // Check if domain or address is already registered
             await this.checkExistingRegistration(agentDomain, agentAddress);
             await this.registerAgent(agentDomain, agentAddress);
         } catch (error) {
             console.error('Registration error:', error);
             this.showStatus('Registration failed: ' + error.message, 'error');
         }
         }

     async checkExistingRegistration(agentDomain, agentAddress) {
         const network = this.networks[this.selectedNetwork];
         // Use read-only provider for checks
         const readProvider = new ethers.providers.JsonRpcProvider(network.rpcUrl);
         const contract = new ethers.Contract(
             network.contracts.identityRegistry,
             this.identityRegistryABI,
             readProvider
         );

         try {
             // Check domain
             const domainResult = await contract.callStatic.resolveByDomain(agentDomain);
             if (domainResult.agentId && domainResult.agentId.gt(0)) {
                 throw new Error(`Domain "${agentDomain}" is already registered with Agent ID ${domainResult.agentId.toString()}`);
             }
         } catch (error) {
             // Domain not found is expected for new registrations
             if (!error.message.includes('AgentNotFound') && !error.message.includes('revert')) {
                 console.log('Domain check error:', error);
             }
         }

         try {
             // Check address
             const addressResult = await contract.callStatic.resolveByAddress(agentAddress);
             if (addressResult.agentId && addressResult.agentId.gt(0)) {
                 throw new Error(`Address "${agentAddress}" is already registered with Agent ID ${addressResult.agentId.toString()}`);
             }
         } catch (error) {
             // Address not found is expected for new registrations
             if (!error.message.includes('AgentNotFound') && !error.message.includes('revert')) {
                 console.log('Address check error:', error);
             }
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
                 <strong>Agent ID:</strong> <span style="font-family: monospace; background: #f3f4f6; padding: 2px 6px; border-radius: 4px;">${agentId}</span><br>
                 <strong>Domain:</strong> ${agentDomain}<br>
                 <strong>Address:</strong> ${agentAddress}<br>
                 <strong>Transaction:</strong> 
                 <a href="${network.explorer}/tx/${tx.hash}" target="_blank" style="color: inherit;">
                     ${tx.hash.substring(0, 10)}...
                 </a>
             `, 'success');
             
             // Clear form
             document.getElementById('agentDomain').value = '';
             document.getElementById('agentAddress').value = '';
            
                 } catch (error) {
             console.log('Registration error details:', error);
             
             if (error.code === 4001) {
                 this.showStatus('Transaction cancelled by user', 'error');
             } else if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
                 // Decode the revert reason
                 const errorData = error.error?.data;
                 if (errorData === '0x7b857a6b') {
                     this.showStatus('⚠️ Domain is already registered! Try using the lookup feature to find the existing registration.', 'error');
                 } else if (errorData === '0x4ca88867') {
                     this.showStatus('⚠️ Address is already registered! This address already has an agent.', 'error');
                 } else if (errorData === '0x5f7b88b5') {
                     this.showStatus('⚠️ Unauthorized registration! You can only register agents for your own address.', 'error');
                 } else {
                     this.showStatus('Registration failed: Transaction would revert. The domain or address might already be registered.', 'error');
                 }
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

     async handleLookup() {
         if (!this.selectedNetwork) {
             this.showStatus('Please select a network', 'error');
             return;
         }
         
         if (!this.provider) {
             this.showStatus('Please connect your wallet first', 'error');
             return;
         }

         const domain = document.getElementById('lookupDomain').value.trim();
         if (!domain) {
             this.showStatus('Please enter a domain to lookup', 'error');
             return;
         }

         try {
             await this.lookupAgent(domain);
         } catch (error) {
             console.error('Lookup error:', error);
             this.showStatus('Lookup failed: ' + error.message, 'error');
         }
     }

     async lookupAgent(domain) {
         const network = this.networks[this.selectedNetwork];
         
         if (!network.contracts.identityRegistry) {
             this.showStatus('Contracts not deployed on this network yet', 'error');
             return;
         }

         this.showStatus('Looking up agent...', 'loading');

         try {
             // Use read-only provider for the selected network (no wallet switch needed)
             const readProvider = new ethers.providers.JsonRpcProvider(network.rpcUrl);
             
             // Create contract instance
             const contract = new ethers.Contract(
                 network.contracts.identityRegistry,
                 this.identityRegistryABI,
                 readProvider
             );

             // Use callStatic to avoid gas estimation issues
             const result = await contract.callStatic.resolveByDomain(domain);
             const { agentId, agentDomain: resolvedDomain, agentAddress } = result;

             if (agentId && agentId.gt(0)) {
                 this.showStatus(`
                     <i class="fas fa-check-circle"></i> 
                     Agent found!<br>
                     <strong>Agent ID:</strong> <span style="font-family: monospace; background: #f3f4f6; padding: 2px 6px; border-radius: 4px;">${agentId.toString()}</span><br>
                     <strong>Domain:</strong> ${resolvedDomain}<br>
                     <strong>Address:</strong> ${agentAddress}<br>
                     <strong>Explorer:</strong> 
                     <a href="${network.explorer}/address/${agentAddress}" target="_blank" style="color: inherit;">
                         View on ${network.name}
                     </a>
                 `, 'success');
             } else {
                 this.showStatus(`No agent found for domain: ${domain}`, 'error');
             }

         } catch (error) {
             console.log('Lookup error details:', error);
             
             // Check if the error contains successful data that ethers.js couldn't decode
             if (error.code === 'CALL_EXCEPTION' && error.data) {
                 try {
                     // Manual decode the return data (AgentInfo struct)
                     const decoded = ethers.utils.defaultAbiCoder.decode(
                         ['tuple(uint256,string,address)'],
                         error.data
                     );
                     
                     const [agentInfo] = decoded;
                     const { 0: agentId, 1: resolvedDomain, 2: agentAddress } = agentInfo;
                     
                     if (agentId && agentId.gt(0)) {
                         this.showStatus(`
                             <i class="fas fa-check-circle"></i> 
                             Agent found!<br>
                             <strong>Agent ID:</strong> <span style="font-family: monospace; background: #f3f4f6; padding: 2px 6px; border-radius: 4px;">${agentId.toString()}</span><br>
                             <strong>Domain:</strong> ${resolvedDomain}<br>
                             <strong>Address:</strong> ${agentAddress}<br>
                             <strong>Explorer:</strong> 
                             <a href="${network.explorer}/address/${agentAddress}" target="_blank" style="color: inherit;">
                                 View on ${network.name}
                             </a>
                         `, 'success');
                         return;
                     }
                 } catch (decodeError) {
                     console.log('Failed to decode error data:', decodeError);
                 }
             }
             
             // If we get here, domain is not registered
             this.showStatus(`Domain "${domain}" is not registered yet`, 'error');
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
    // Check if ethers.js loaded properly
    if (typeof ethers === 'undefined') {
        console.error('❌ ethers.js failed to load from CDN');
        document.getElementById('walletStatus').innerHTML = `
            <i class="fas fa-exclamation-triangle" style="color: #ef4444;"></i>
            Failed to load Web3 libraries. Please refresh the page.
        `;
        return;
    }
    
    console.log('✅ ethers.js loaded successfully:', ethers.version);
    window.trustlessAgentsApp = new TrustlessAgentsApp();
});

// Example of how to update contract addresses after deployment:
// window.trustlessAgentsApp.updateContractAddresses('sepolia', {
//     identityRegistry: '0x...',
//     reputationRegistry: '0x...',
//     validationRegistry: '0x...'
// });
