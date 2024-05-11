const { ethers, upgrades } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const Oracle = await ethers.getContractFactory("Oracle");
    console.log("Deploying Oracle...");

    const oracle = await upgrades.deployProxy(Oracle, [deployer.address], { initializer: 'initialize' });

    console.log("Oracle deployed to:", oracle.address);
    console.log("Oracle owner set to:", deployer.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
