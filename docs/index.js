import tokenMessengerAbi from './abis/TokenMessenger.json' assert { type: 'json' };
import messageTransmitterAbi from './abis/MessageTransmitter.json' assert { type: 'json' };
import messageAbi from './abis/Message.json' assert { type: 'json' };
import usdcAbi from './abis/Usdc.json' assert { type: 'json' };

async function main() {
    // Connect to Metamask Wallet
    const provider = new ethers.providers.Web3Provider(window.ethereum)
    const signer = provider.getSigner()

    // Testnet Contract Addresses
    const ETH_TOKEN_MESSENGER_CONTRACT_ADDRESS = "0xd0c3da58f55358142b8d3e06c1c30c5c6114efe8";
    const USDC_ETH_CONTRACT_ADDRESS = "0x07865c6e87b9f70255377e024ace6630c1eaa37f";
    const ETH_MESSAGE_CONTRACT_ADDRESS = "0x1a9695e9dbdb443f4b20e3e4ce87c8d963fda34f"
    const AVAX_MESSAGE_TRANSMITTER_CONTRACT_ADDRESS = '0xa9fb1b3009dcb79e2fe346c16a604b8fa8ae0a79';
    
    // initialize contracts using address and ABI
    const ethTokenMessengerContract = new ethers.Contract(ETH_TOKEN_MESSENGER_CONTRACT_ADDRESS, tokenMessengerAbi, signer);
    const usdcEthContract = new ethers.Contract(USDC_ETH_CONTRACT_ADDRESS, usdcAbi, signer);
    const ethMessageContract = new ethers.Contract(ETH_MESSAGE_CONTRACT_ADDRESS, messageAbi, signer);
    const avaxMessageTransmitterContract = new ethers.Contract(AVAX_MESSAGE_TRANSMITTER_CONTRACT_ADDRESS, messageTransmitterAbi, signer);

    // AVAX destination address
    const mintRecipient = "<YOUR_AVAX_ADDRESS>";
    const destinationAddressInBytes32 = await ethMessageContract.addressToBytes32(mintRecipient);
    const AVAX_DESTINATION_DOMAIN = 1;
    
    // STEP 0: Approve messenger contract to withdraw from our active metamask address
    // const approveTx = await usdcEthContract.approve(TOKEN_MESSENGER_CONTRACT_ADDRESS, 500000) // 0.5 USDC
    // console.log(`ApproveTx: ${approveTx.hash}`)
    
    // Wait for transaction to complete
    // const approveTxReceipt = await provider.waitForTransaction(approveTx.hash)
    // console.log(`ApproveTxReceipt: ${approveTxReceipt}`)
    
    // STEP 1: Burn USDC
    const amount = 100000 // 0.1 USDC
    const burnTx = await ethTokenMessengerContract.depositForBurn(amount, AVAX_DESTINATION_DOMAIN, destinationAddressInBytes32, USDC_CONTRACT_ADDRESS);
    console.log(`BurnTx: ${burnTx}`)

    // Wait for transaction to complete
    const burnTxReceipt = await provider.waitForTransaction(burnTx.hash)
    console.log(`BurnTxReceipt: ${burnTxReceipt}`)

    // STEP 2: Retrieve message bytes from logs
    const transactionReceipt = await provider.getTransactionReceipt(burnTx.hash);
    const eventTopic = ethers.utils.id('MessageSent(bytes)')
    const log = transactionReceipt.logs.find((l) => l.topics[0] === eventTopic)
    const messageBytes = ethers.utils.defaultAbiCoder.decode(['bytes'], log.data)[0]
    const messageHash = ethers.utils.keccak256(messageBytes);

    console.log(`MessageBytes: ${messageBytes}`)
    console.log(`MessageHash: ${messageHash}`)

    // STEP 3: Fetch attestation signature
    let attestationResponse;
    while(attestationResponse.status != 'complete') {
        const response = await fetch(`https://iris-api-sandbox.circle.com/attestations/${messageHash}`);
        attestationResponse = await response.json()
        await new Promise(r => setTimeout(r, 2000));
    }

    const attestationSignature = attestationResponse.attestation;
    console.log(`Signature: ${attestationSignature}`)

    // STEP 4: Using the message bytes and signature recieve the funds on destination chain and address
    const receivingMessageBytes = '<ADD_MESSAGE_BYTES_HERE>'
    const signature = '<ADD_SIGNATURE_HERE>'
    const receiveTx = await avaxMessageTransmitterContract.receiveMessage(receivingMessageBytes, signature);
    console.log(`ReceiveTx: ${receiveTx}`)
}

main()
