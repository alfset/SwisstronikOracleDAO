const hre = require("hardhat");

async function main() {
  const JAN_1ST_2030 = 1893456000; 
  const ONE_GWEI = hre.ethers.parseUnits("1", "gwei");

  console.log("Deploying contract...");
  const Lock = await hre.ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(JAN_1ST_2030, { value: ONE_GWEI });

  console.log("Waiting for deployment...");
  await lock.deployed();
  console.log(`Contract deployed to: ${lock.address}`);

  console.log("Pausing 5 seconds to ensure that the contract is picked up by Etherscan...");
  await delay(5000);

  console.log("Verifying contract on Etherscan...");
  try {
    await hre.run("verify:verify", {
      address: lock.address,
      constructorArguments: [JAN_1ST_2030],
    });
    console.log("Contract verified!");
  } catch (err) {
    console.error("Error verifying contract. Reason:", err.message);
  }
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("An error occurred:", error);
  process.exitCode = 1;
});
