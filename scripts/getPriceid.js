const hre = require("hardhat");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

async function main() {
    const contractAddress = "0xA1bB5791dC0d6939Bf05AEbCB57DBaeBd46684a4";
    const [signer] = await hre.ethers.getSigners();
    const Oracle = await hre.ethers.getContractFactory("Oracle");
    const oracle = Oracle.attach(contractAddress);

    const symbols = ["BTCUSD", "ETHUSD", "ATOMUSD", "BTCETH", "BTCATOM", "ETHATOM", "PLANQUSD", "BTCPLANQ", "ETHPLANQ", "ATOMPLANQ"];

    for (let symbol of symbols) {
        const functionName = "getPriceId"; 

        const encodedFunctionData = oracle.interface.encodeFunctionData(functionName, [symbol]);
        const encryptedQueryResponse = await sendShieldedQuery(signer.provider, contractAddress, encodedFunctionData);

        const priceId = oracle.interface.decodeFunctionResult(functionName, encryptedQueryResponse)[0];
        console.log(`The price ID for ${symbol} is:`, priceId);
    }
}

const sendShieldedQuery = async (provider, destination, data) => {
    const rpclink = hre.network.config.url;
    const [encryptedData, usedEncryptedKey] = await encryptDataField(rpclink, data);
    const response = await provider.call({
        to: destination,
        data: encryptedData,
    });
    return await decryptNodeResponse(rpclink, response, usedEncryptedKey);
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
