// ERC-8004 Contract Addresses Configuration
// Update these addresses after deployment

window.CONTRACT_ADDRESSES = {
    sepolia: {
        identityRegistry: "0x127C86a24F46033E77C347258354ee4C739b139C",
        reputationRegistry: "0x57396214E6E65E9B3788DE7705D5ABf3647764e0",
        validationRegistry: "0x5d332cE798e491feF2de260bddC7f24978eefD85"
    },
    base_sepolia: {
        identityRegistry: "0x19fad4adD9f8C4A129A078464B22E1506275FbDd",
        reputationRegistry: "0xA13497975fd3f6cA74081B074471C753b622C903",
        validationRegistry: "0x6e24aA15e134AF710C330B767018d739CAeCE293"
    },
    arbitrum_sepolia: {
        identityRegistry: "",
        reputationRegistry: "",
        validationRegistry: ""
    },
    optimism_sepolia: {
        identityRegistry: "0x19fad4adD9f8C4A129A078464B22E1506275FbDd",
        reputationRegistry: "0xA13497975fd3f6cA74081B074471C753b622C903",
        validationRegistry: "0x6e24aA15e134AF710C330B767018d739CAeCE293"
    }
};

console.log('✅ Contract addresses loaded:', window.CONTRACT_ADDRESSES);
