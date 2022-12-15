pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/TokenMessenger.sol";
import "../src/TokenMinter.sol";
import "../src/MessageTransmitter.sol";
import "../src/messages/Message.sol";

contract DeployScript is Script {
    address private attesterAddress;
    address private usdcContractAddress;
    address private usdcRemoteContractAddress;
    address private remoteTokenMessengerAddress;
    address private tokenControllerAddress;
    address private messageTransmitterPauserAddress;
    address private tokenMinterPauserAddress;
    address private messageTransmitterRescuerAddress;
    address private tokenMessengerRescuerAddress;
    address private tokenMinterRescuerAddress;

    uint32 private messageBodyVersion = 0;
    uint32 private version = 0;
    uint32 private domain;
    uint32 private remoteDomain;
    uint32 private maxMessageBodySize = 8192;
    uint256 private burnLimitPerMessage;

    uint256 private messageTransmitterDeployerPrivateKey;
    uint256 private tokenMessengerDeployerPrivateKey;
    uint256 private tokenMinterDeployerPrivateKey;
    uint256 private tokenControllerPrivateKey;

    /**
     * @notice deploys Message Transmitter
     * @param privateKey Private Key for signing the transactions
     * @return MessageTransmitter instance
     */
    function deployMessageTransmitter(uint256 privateKey)
        private
        returns (MessageTransmitter)
    {
        // Start recording transactions
        vm.startBroadcast(privateKey);

        // Deploy MessageTransmitter
        MessageTransmitter messageTransmitter = new MessageTransmitter(
            domain,
            attesterAddress,
            maxMessageBodySize,
            version
        );

        // Add Pauser
        messageTransmitter.updatePauser(messageTransmitterPauserAddress);

        // Add Rescuer
        messageTransmitter.updateRescuer(messageTransmitterRescuerAddress);

        // Stop recording transactions
        vm.stopBroadcast();
        return messageTransmitter;
    }

    /**
     * @notice deploys TokenMessenger
     * @param privateKey Private Key for signing the transactions
     * @param messageTransmitterAddress Message Transmitter Contract address
     * @return TokenMessenger instance
     */
    function deployTokenMessenger(
        uint256 privateKey,
        address messageTransmitterAddress
    ) private returns (TokenMessenger) {
        // Start recording transations
        vm.startBroadcast(privateKey);

        // Deploy TokenMessenger
        TokenMessenger tokenMessenger = new TokenMessenger(
            messageTransmitterAddress,
            messageBodyVersion
        );

        // Add Rescuer
        tokenMessenger.updateRescuer(tokenMessengerRescuerAddress);

        // Stop recording transations
        vm.stopBroadcast();

        return tokenMessenger;
    }

    /**
     * @notice deploys TokenMinter
     * @param privateKey Private Key for signing the transactions
     * @param tokenMessengerAddress TokenMessenger Contract address
     * @return TokenMinter instance
     */
    function deployTokenMinter(
        uint256 privateKey,
        address tokenMessengerAddress
    ) private returns (TokenMinter) {
        // Start recording transations
        vm.startBroadcast(privateKey);

        // Deploy TokenMinter
        TokenMinter tokenMinter = new TokenMinter(tokenControllerAddress);

        // Add Local TokenMessenger
        tokenMinter.addLocalTokenMessenger(tokenMessengerAddress);

        // Add Pauser
        tokenMinter.updatePauser(tokenMinterPauserAddress);

        // Add Rescuer
        tokenMinter.updateRescuer(tokenMinterRescuerAddress);

        // Stop recording transations
        vm.stopBroadcast();

        return tokenMinter;
    }

    /**
     * @notice add local minter to the TokenMessenger
     */
    function addMinterAddressToTokenMessenger(
        TokenMessenger tokenMessenger,
        uint256 privateKey,
        address minterAddress
    ) private {
        // Start recording transations
        vm.startBroadcast(privateKey);

        tokenMessenger.addLocalMinter(minterAddress);

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice link current chain and remote chain tokens
     */
    function linkTokenPair(TokenMinter tokenMinter, uint256 privateKey)
        private
    {
        // Start recording transations
        vm.startBroadcast(privateKey);

        bytes32 remoteUsdcContractAddressInBytes32 = Message.addressToBytes32(
            usdcRemoteContractAddress
        );

        tokenMinter.setMaxBurnAmountPerMessage(
            usdcContractAddress,
            burnLimitPerMessage
        );

        tokenMinter.linkTokenPair(
            usdcContractAddress,
            remoteDomain,
            remoteUsdcContractAddressInBytes32
        );

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice add address of TokenMessenger deployed on another chain
     */
    function addRemoteTokenMessenger(
        TokenMessenger tokenMessenger,
        uint256 privateKey
    ) private {
        // Start recording transations
        vm.startBroadcast(privateKey);
        bytes32 remoteTokenMessengerAddressInBytes32 = Message.addressToBytes32(
            remoteTokenMessengerAddress
        );
        tokenMessenger.addRemoteTokenMessenger(
            remoteDomain,
            remoteTokenMessengerAddressInBytes32
        );

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        messageTransmitterDeployerPrivateKey = vm.envUint(
            "MESSAGE_TRANSMITTER_DEPLOYER_KEY"
        );
        tokenMessengerDeployerPrivateKey = vm.envUint(
            "TOKEN_MESSENGER_DEPLOYER_KEY"
        );
        tokenMinterDeployerPrivateKey = vm.envUint("TOKEN_MINTER_DEPLOYER_KEY");
        tokenControllerPrivateKey = vm.envUint("TOKEN_CONTROLLER_DEPLOYER_KEY");

        attesterAddress = vm.envAddress("ATTESTER_ADDRESS");
        usdcContractAddress = vm.envAddress("USDC_CONTRACT_ADDRESS");
        tokenControllerAddress = vm.envAddress("TOKEN_CONTROLLER_ADDRESS");
        burnLimitPerMessage = vm.envUint("BURN_LIMIT_PER_MESSAGE");

        usdcRemoteContractAddress = vm.envAddress(
            "REMOTE_USDC_CONTRACT_ADDRESS"
        );

        remoteTokenMessengerAddress = vm.envAddress(
            "REMOTE_TOKEN_MESSENGER_ADDRESS"
        );

        domain = uint32(vm.envUint("DOMAIN"));
        remoteDomain = uint32(vm.envUint("REMOTE_DOMAIN"));

        messageTransmitterPauserAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_PAUSER_ADDRESS"
        );
        tokenMinterPauserAddress = vm.envAddress("TOKEN_MINTER_PAUSER_ADDRESS");

        messageTransmitterRescuerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_RESCUER_ADDRESS"
        );
        tokenMessengerRescuerAddress = vm.envAddress(
            "TOKEN_MESSENGER_RESCUER_ADDRESS"
        );
        tokenMinterRescuerAddress = vm.envAddress(
            "TOKEN_MINTER_RESCUER_ADDRESS"
        );
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        // Deploy MessageTransmitter
        MessageTransmitter messageTransmitter = deployMessageTransmitter(
            messageTransmitterDeployerPrivateKey
        );

        // Deploy TokenMessenger
        TokenMessenger tokenMessenger = deployTokenMessenger(
            tokenMessengerDeployerPrivateKey,
            address(messageTransmitter)
        );

        // Deploy TokenMinter
        TokenMinter tokenMinter = deployTokenMinter(
            tokenMinterDeployerPrivateKey,
            address(tokenMessenger)
        );

        // Add Local Minter
        addMinterAddressToTokenMessenger(
            tokenMessenger,
            tokenMessengerDeployerPrivateKey,
            address(tokenMinter)
        );

        // Link token pair and add remote token messenger
        linkTokenPair(tokenMinter, tokenControllerPrivateKey);
        addRemoteTokenMessenger(
            tokenMessenger,
            tokenMessengerDeployerPrivateKey
        );
    }
}
