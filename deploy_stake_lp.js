
async function main() {
    // We get the contract to deploy
    const contract = await ethers.getContractFactory('StakingTokenLP');
    console.log('Deploying Staking Token LP...');
    /**
     * mainnet
     * @type {string}
     */
    // const dfhToken = '0x945d9AF572a89627B29aafa0E3B66e4f867E32a7'
    // const lpToken = '0xc5f99B900bfe4C29a559d0D22d3eE01f4c533c1F' // Pancake
    // const lpToken = '0x8eFedc15477482320AD2b727d8BFD3Bf75A75e43' // Kyper

    /** testnet
     *
     * @type {string}
     */
    const dfhToken = '0xFC15F942F73039EA377C4da9d41FDA32E56E5aa4'
    const lpToken = '0x79C223E55A7579A91D2C031029b9AD4cC0918d79'

    const token = await contract.deploy(dfhToken, lpToken);
    await token.deployed();
    console.log('Staking Token LP deployed to:', token.address);
    console.log(`Please enter this command below to verify your contract:`)
    console.log(`npx hardhat verify --network ${token.deployTransaction.chainId === 56 ? 'mainnet' : 'testnet'} ${token.address} ${dfhToken} ${lpToken}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
