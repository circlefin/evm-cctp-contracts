pragma solidity 0.7.6;

import "forge-std/Script.sol";
import "../../src/TokenMessenger.sol";
import "../../src/TokenMinter.sol";
import "../../src/MessageTransmitter.sol";

contract RotateKeysScript is Script {
    address private messageTransmitterContractAddress;
    address private tokenMessengerContractAddress;
    address private tokenMinterContractAddress;
    address private newTokenControllerAddress;

    uint256 private messageTransmitterDeployerPrivateKey;
    uint256 private tokenMessengerDeployerPrivateKey;
    uint256 private tokenMinterDeployerPrivateKey;

    address private messageTransmitterNewOwnerAddress;
    address private tokenMessengerNewOwnerAddress;
    address private tokenMinterNewOwnerAddress;

    function rotateMessageTransmitterOwner(uint256 privateKey) public {
        // load messageTransmitter
        MessageTransmitter messageTransmitter = MessageTransmitter(
            messageTransmitterContractAddress
        );

        vm.startBroadcast(privateKey);

        messageTransmitter.transferOwnership(messageTransmitterNewOwnerAddress);

        vm.stopBroadcast();
    }

    function rotateTokenMessengerOwner(uint256 privateKey) public {
        TokenMessenger tokenMessenger = TokenMessenger(
            tokenMessengerContractAddress
        );

        vm.startBroadcast(privateKey);

        tokenMessenger.transferOwnership(tokenMessengerNewOwnerAddress);

        vm.stopBroadcast();
    }

    function rotateTokenControllerThenTokenMinterOwner(
        uint256 privateKey
    ) public {
        TokenMinter tokenMinter = TokenMinter(tokenMinterContractAddress);

        vm.startBroadcast(privateKey);

        tokenMinter.setTokenController(newTokenControllerAddress);

        tokenMinter.transferOwnership(tokenMinterNewOwnerAddress);

        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        messageTransmitterContractAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_CONTRACT_ADDRESS"
        );

        tokenMessengerContractAddress = vm.envAddress(
            "TOKEN_MESSENGER_CONTRACT_ADDRESS"
        );

        tokenMinterContractAddress = vm.envAddress(
            "TOKEN_MINTER_CONTRACT_ADDRESS"
        );

        messageTransmitterDeployerPrivateKey = vm.envUint(
            "MESSAGE_TRANSMITTER_DEPLOYER_KEY"
        );
        tokenMessengerDeployerPrivateKey = vm.envUint(
            "TOKEN_MESSENGER_DEPLOYER_KEY"
        );
        tokenMinterDeployerPrivateKey = vm.envUint("TOKEN_MINTER_DEPLOYER_KEY");

        messageTransmitterNewOwnerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_NEW_OWNER_ADDRESS"
        );

        tokenMessengerNewOwnerAddress = vm.envAddress(
            "TOKEN_MESSENGER_NEW_OWNER_ADDRESS"
        );

        tokenMinterNewOwnerAddress = vm.envAddress(
            "TOKEN_MINTER_NEW_OWNER_ADDRESS"
        );

        newTokenControllerAddress = vm.envAddress(
            "NEW_TOKEN_CONTROLLER_ADDRESS"
        );
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        setUp();

        rotateMessageTransmitterOwner(messageTransmitterDeployerPrivateKey);
        rotateTokenMessengerOwner(tokenMessengerDeployerPrivateKey);
        rotateTokenControllerThenTokenMinterOwner(
            tokenMinterDeployerPrivateKey
        );
    }
}
