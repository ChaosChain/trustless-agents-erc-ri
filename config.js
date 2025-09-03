// ERC-8004 Contract Addresses Configuration
// Update these addresses after deployment

const CONTRACT_ADDRESSES = {
    sepolia: {
        identityRegistry: "",
        reputationRegistry: "",
        validationRegistry: ""
    },
    base_sepolia: {
        identityRegistry: "",
        reputationRegistry: "",
        validationRegistry: ""
    },
    arbitrum_sepolia: {
        identityRegistry: "",
        reputationRegistry: "",
        validationRegistry: ""
    },
    optimism_sepolia: {
        identityRegistry: "",
        reputationRegistry: "",
        validationRegistry: ""
    }
};

// Auto-update contract addresses when config loads
if (typeof window !== 'undefined' && window.trustlessAgentsApp) {
    Object.entries(CONTRACT_ADDRESSES).forEach(([network, addresses]) => {
        window.trustlessAgentsApp.updateContractAddresses(network, addresses);
    });
}
