
# Quickstart: Cross-chain USDC Transfer

This example uses [Ethers.js](https://docs.ethers.org/v5/getting-started/) and [Metamask](https://metamask.io/) to transfer USDC from address on ETH testnet to another address AVAX testnet. The script has 4 steps and can be run in 2 parts. Run steps 1 to 3 require Goerli testnet selected in Metamask with associated active address. Step 4 require changing the network to Avalance Fuji testnet with associated active address.

Following guide provides step by step instruction on how to run the script:
1. Start a local server by running `python3 -m http.server 8000` in the folder.
2. Switch to Goerli test network and active address with some USDC and ETH in Metamask browser extension.
3. Go to `http://localhost:8000` in browser and keep the console opened.
4. When running this script first time, you will notice a badge appear on Metamask extension. It needs permission to be able to connect to the site (localhost).
```js
const provider = new ethers.providers.Web3Provider(window.ethereum)
const signer = provider.getSigner()
```
5. Next, call the `depositForBurn` function on `TokenMessengerContract` deployed in [Goerli testnet](https://goerli.etherscan.io/address/0xd0c3da58f55358142b8d3e06c1c30c5c6114efe8). Metamask will ask for this transaction to be approved.
```js
const burnTx = await ethTokenMessengerContract.depositForBurn(amount, AVAX_DESTINATION_DOMAIN, destinationAddressInBytes32, USDC_CONTRACT_ADDRESS);
```
*Note: When running this function on your own node, you can use ERC20 [approve function](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20) as described in step 0 of the script to allow `TokenMessengerContract` to withdraw USDC from your account.*
```js
const approveTx = await usdcEthContract.approve(TOKEN_MESSENGER_CONTRACT_ADDRESS, 500000) // 0.5 USDC
```

6. We then need to extract `messageBytes` from the above transaction logs.
```js
const transactionReceipt = await provider.getTransactionReceipt(burnTx.hash);
const eventTopic = ethers.utils.id('MessageSent(bytes)')
const log = transactionReceipt.logs.find((l) => l.topics[0] === eventTopic)
const messageBytes = ethers.utils.defaultAbiCoder.decode(['bytes'], log.data)[0]
```
7. Hash the retrived `messageBytes` using `keccak256` algorithm.
```js
const messageHash = ethers.utils.keccak256(messageBytes);
```
8. Call attestation service to acquire signature using the `messageHash` from previous step.
```js
const response = await fetch(`https://iris-api-sandbox.circle.com/attestations/${messageHash}`);
const attestationResponse = await response.json()
const signature = attestationResponse.attestation;
```
9. Switch to Avalanche Fuji Network and active address with some AVAX in Metamask.
10. Populate the below fields in step 4 of the script using the `messageBytes` and `signature` gathered in previous steps.
```js
const receivingMessageBytes = '<ADD_MESSAGE_BYTES_HERE>'
const signature = '<ADD_SIGNATURE_HERE>'
```
11. Call `receiveMessage` function on `TokenMessengerContract` deployed in [Avalanche Fuji Network](https://testnet.snowtrace.io/address/0xa9fb1b3009dcb79e2fe346c16a604b8fa8ae0a79)
```js
const receiveTx = await avaxMessageTransmitterContract.receiveMessage(receivingMessageBytes, signature);
```
12. Allow Metamask to complete the transaction. 
13. Check for transaction with `ReceiveMessage` method on [block explorer](https://testnet.snowtrace.io/).