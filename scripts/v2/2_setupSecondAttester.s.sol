pragma solidity 0.7.6;

import "forge-std/Script.sol";
import "../../src/MessageTransmitter.sol";

contract SetupSecondAttesterScript is Script {
    address private secondAttesterAddress;
    address private newAttesterManagerAddress;
    address private messageTransmitterContractAddress;

    uint256 private attesterManagerPrivateKey;

    function configureSecondAttesterThenRotateAttesterManager(
        uint256 privateKey
    ) public {
        MessageTransmitter messageTransmitter = MessageTransmitter(
            messageTransmitterContractAddress
        );

        vm.startBroadcast(privateKey);

        // enable second attester
        messageTransmitter.enableAttester(secondAttesterAddress);

        // setSignatureThreshold to 2
        messageTransmitter.setSignatureThreshold(2);

        // updateAttesterManager
        messageTransmitter.updateAttesterManager(newAttesterManagerAddress);

        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        messageTransmitterContractAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_CONTRACT_ADDRESS"
        );

        attesterManagerPrivateKey = vm.envUint(
            "MESSAGE_TRANSMITTER_DEPLOYER_KEY"
        );

        newAttesterManagerAddress = vm.envAddress(
            "NEW_ATTESTER_MANAGER_ADDRESS"
        );

        secondAttesterAddress = vm.envAddress("SECOND_ATTESTER_ADDRESS");
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        setUp();

        configureSecondAttesterThenRotateAttesterManager(
            attesterManagerPrivateKey
        );
    }
}
