pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/CircleBridge.sol";
import "../src/CircleMinter.sol";
import "../src/MessageTransmitter.sol";
import "../src/messages/Message.sol";

contract DeployScript is Script {
    address private attesterAddress;
    address private usdcContractAddress;
    address private usdcRemoteContractAddress;
    address private remoteBridgeAddress;

    bool private remoteAvailable = false;

    uint32 private messageBodyVersion = 0;
    uint32 private version = 0;
    uint32 private domain = 0;
    uint32 private remoteDomain = 1;
    uint32 private maxMessageBodySize = 8192;

    uint256 private messageTransmitterDeployerPrivateKey;
    uint256 private circleBridgeDeployerPrivateKey;
    uint256 private circleMinterDeployerPrivateKey;

    /**
     * @notice deploys Message Transmitter
     * @param privateKey Private Key for siginig the transactions
     * @return MessageTransmitter instance
     */
    function deployMessageTransmitter(uint256 privateKey)
        private
        returns (MessageTransmitter)
    {
        vm.startBroadcast(privateKey);
        MessageTransmitter messageTransmitter = new MessageTransmitter(
            domain,
            attesterAddress,
            maxMessageBodySize,
            version
        );
        vm.stopBroadcast();
        return messageTransmitter;
    }

    /**
     * @notice deploys circle bridge
     * @param privateKey Private Key for siginig the transactions
     * @param messageTransmitterAddress Message Transmitter Contract address
     * @return CircleBridge instance
     */
    function deployCircleBridge(
        uint256 privateKey,
        address messageTransmitterAddress
    ) private returns (CircleBridge) {
        // Start recording transations
        vm.startBroadcast(privateKey);

        // Deploy Bridge
        CircleBridge circleBridge = new CircleBridge(
            messageTransmitterAddress,
            messageBodyVersion
        );

        // Stop recording transations
        vm.stopBroadcast();

        return circleBridge;
    }

    /**
     * @notice deploys circle minter
     * @param privateKey Private Key for siginig the transactions
     * @param circleBridgeAddress Circle Bridge Contract address
     * @return CircleMinter instance
     */
    function deployCircleMinter(uint256 privateKey, address circleBridgeAddress)
        private
        returns (CircleMinter)
    {
        // Start recording transations
        vm.startBroadcast(privateKey);

        // Deploy CircleMinter
        CircleMinter circleMinter = new CircleMinter();

        // Add Local Bridge
        circleMinter.addLocalCircleBridge(circleBridgeAddress);

        // Set setLocalTokenEnabledStatus
        circleMinter.setLocalTokenEnabledStatus(usdcContractAddress, true);

        // Stop recording transations
        vm.stopBroadcast();

        return circleMinter;
    }

    /**
     * @notice add local minter to the bridge
     */
    function addMinterAddressToBridge(
        CircleBridge circleBridge,
        uint256 privateKey,
        address minterAddress
    ) private {
        // Start recording transations
        vm.startBroadcast(privateKey);

        circleBridge.addLocalMinter(minterAddress);

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice link current chain and remote chain tokens
     */
    function linkTokenPair(CircleMinter circleMinter, uint256 privateKey)
        private
    {
        // Start recording transations
        vm.startBroadcast(privateKey);

        bytes32 remoteUsdcContractAddressInBytes32 = Message.addressToBytes32(
            usdcRemoteContractAddress
        );
        circleMinter.linkTokenPair(
            usdcContractAddress,
            remoteDomain,
            remoteUsdcContractAddressInBytes32
        );

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice add address of bridge deployed on another chain
     */
    function addRemoteBridge(CircleBridge circleBridge, uint256 privateKey)
        private
    {
        // Start recording transations
        vm.startBroadcast(privateKey);
        bytes32 remoteBridgeAddressInBytes32 = Message.addressToBytes32(
            remoteBridgeAddress
        );
        circleBridge.addRemoteCircleBridge(
            remoteDomain,
            remoteBridgeAddressInBytes32
        );

        // Stop recording transations
        vm.stopBroadcast();
    }

    /**
     * @notice initilize variables from environment
     */
    function setUp() public {
        messageTransmitterDeployerPrivateKey = vm.envUint(
            "MESSAGE_TRANSMITTER_DEPLOYER_KEY"
        );
        circleBridgeDeployerPrivateKey = vm.envUint(
            "CIRCLE_BRIDGE_DEPLOYER_KEY"
        );
        circleMinterDeployerPrivateKey = vm.envUint(
            "CIRCLE_MINTER_DEPLOYER_KEY"
        );

        attesterAddress = vm.envAddress("ATTESTER_ADDRESS");
        usdcContractAddress = vm.envAddress("USDC_CONTRACT_ADDRESS");

        remoteAvailable = vm.envBool("REMOTE_AVAILABLE");
        if (remoteAvailable == true) {
            usdcRemoteContractAddress = vm.envAddress(
                "REMOTE_USDC_CONTRACT_ADDRESS"
            );
            remoteBridgeAddress = vm.envAddress("REMOTE_BRIDGE_ADDRESS");
        }
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        // Deploy MessageTransmitter
        MessageTransmitter messageTransmitter = deployMessageTransmitter(
            messageTransmitterDeployerPrivateKey
        );

        // Deploy CircleBridge
        CircleBridge circleBridge = deployCircleBridge(
            circleBridgeDeployerPrivateKey,
            address(messageTransmitter)
        );

        // Deploy CircleMinter
        CircleMinter circleMinter = deployCircleMinter(
            circleMinterDeployerPrivateKey,
            address(circleBridge)
        );

        // Add Local Minter
        addMinterAddressToBridge(
            circleBridge,
            circleBridgeDeployerPrivateKey,
            address(circleMinter)
        );

        // Link token pair and add remote bridge
        if (remoteAvailable == true) {
            linkTokenPair(circleMinter, circleMinterDeployerPrivateKey);
            addRemoteBridge(circleBridge, circleBridgeDeployerPrivateKey);
        }
    }
}
