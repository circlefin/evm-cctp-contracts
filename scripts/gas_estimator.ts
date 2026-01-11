/* eslint-disable no-console */

import { ethers } from "hardhat";

/**
 * Estimate gas usage for key functions on the CCTP contracts.
 * Run with: npx hardhat run scripts/gas_estimator.ts --network <network>
 */
async function main() {
  const transmitterAddress = process.env.MESSAGE_TRANSMITTER_ADDRESS!;
  const transmitter = await ethers.getContractAt("MessageTransmitter", transmitterAddress);

  // Prepare a dummy message to estimate cost
  const dummy = {
    recipient: "0x0000000000000000000000000000000000000000",
    amount: 1,
    message: "0x"
  };

  const gas = await transmitter.estimateGas.sendMessage(dummy.recipient, dummy.amount, dummy.message);
  console.log(`Estimated gas to sendMessage: ${gas.toString()}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
