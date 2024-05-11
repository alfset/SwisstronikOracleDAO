const hre = require("hardhat");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

async function main() {
    const contractAddress = "0xA1bB5791dC0d6939Bf05AEbCB57DBaeBd46684a4";
    const newOwnerAddress = "0x448EF2c70c93F19CC01B7D0768B42F9c61AB9748"; 
    const [signer] = await hre.ethers.getSigners();
    const Oracle = await hre.ethers.getContractFactory("Oracle");
    const oracle = Oracle.attach(contractAddress);

    const ownerFunctionName = "owner";  
    const encryptedQueryResponse = await sendShieldedQuery(signer.provider, contractAddress, oracle.interface.encodeFunctionData(ownerFunctionName));
    const currentOwner = oracle.interface.decodeFunctionResult(ownerFunctionName, encryptedQueryResponse)[0];
    console.log("Current owner:", currentOwner);

    if (currentOwner.toLowerCase() !== signer.address.toLowerCase()) {
        console.error("The signer is not the current owner and cannot transfer ownership.");
        return;
    }

    const transferOwnershipFunctionName = "transferOwnership";
    const txData = oracle.interface.encodeFunctionData(transferOwnershipFunctionName, [newOwnerAddress]);
    const encryptedTxResponse = await sendShieldedTransaction(signer.provider, contractAddress, txData);
    console.log("Ownership transfer initiated:", encryptedTxResponse);
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

const sendShieldedTransaction = async (provider, destination, data) => {
    const rpclink = hre.network.config.url;
    const [encryptedData, usedEncryptedKey] = await encryptDataField(rpclink, data);
    const transaction = {
        to: destination,
        data: encryptedData,
    };
    const txResponse = await provider.send('eth_sendTransaction', [transaction]);
    return await decryptNodeResponse(rpclink, txResponse, usedEncryptedKey);
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
