/*
 * Copyright 2024 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;
pragma abicoder v2;

import {Script} from "forge-std/Script.sol";
import {Create2Factory} from "../../src/v2/Create2Factory.sol";
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";
import {SALT_TOKEN_MESSENGER, SALT_MESSAGE_TRANSMITTER} from "./Salts.sol";
import {PredictCreate2Deployments} from "./PredictCreate2Deployments.s.sol";

contract DeployProxiesV2Script is Script {
    // Expose for tests
    MessageTransmitterV2 public messageTransmitterV2;
    TokenMessengerV2 public tokenMessengerV2;

    address private usdcContractAddress;
    address private create2Factory;
    uint32[] private remoteDomains;
    bytes32[] private usdcRemoteContractAddresses;
    bytes32[] private remoteTokenMessengerV2Addresses;

    address private messageTransmitterV2Implementation;
    address private messageTransmitterV2OwnerAddress;
    address private messageTransmitterV2PauserAddress;
    address private messageTransmitterV2RescuerAddress;
    address private messageTransmitterV2AttesterManagerAddress;
    address private messageTransmitterV2Attester1Address;
    address private messageTransmitterV2Attester2Address;
    uint256 private messageTransmitterV2SignatureThreshold = 2;
    address private messageTransmitterV2AdminAddress;

    TokenMinterV2 private tokenMinterV2;
    address private tokenMinterV2PauserAddress;
    address private tokenMinterV2RescuerAddress;

    address private tokenMessengerV2Implementation;
    address private tokenMessengerV2OwnerAddress;
    address private tokenMessengerV2PauserAddress;
    address private tokenMessengerV2RescuerAddress;
    address private tokenMessengerV2FeeRecipientAddress;
    address private tokenMessengerV2DenylisterAddress;
    address private tokenMessengerV2AdminAddress;

    uint32 private domain;
    uint32 private version;
    uint32 private messageBodyVersion;
    uint32 private maxMessageBodySize = 8192;
    uint256 private burnLimitPerMessage;

    address private create2FactoryOwner;
    uint256 private tokenMinterV2OwnerPrivateKey;
    uint256 private tokenControllerPrivateKey;

    PredictCreate2Deployments predictDeployments =
        new PredictCreate2Deployments();

    function getProxyCreationCode(
        address _implementation,
        address _admin,
        bytes memory _data
    ) public pure returns (bytes memory) {
        return
            abi.encodePacked(
                type(AdminUpgradableProxy).creationCode,
                abi.encode(_implementation, _admin, _data)
            );
    }

    function deployMessageTransmitterV2(
        address factory,
        address factoryOwner
    ) private returns (MessageTransmitterV2) {
        // Get proxy creation code
        bytes memory proxyCreateCode = getProxyCreationCode(
            factory,
            factory,
            ""
        );

        // Construct initializer
        address[] memory attesters = new address[](2);
        attesters[0] = messageTransmitterV2Attester1Address;
        attesters[1] = messageTransmitterV2Attester2Address;
        bytes memory initializer = abi.encodeWithSelector(
            MessageTransmitterV2.initialize.selector,
            messageTransmitterV2OwnerAddress,
            messageTransmitterV2PauserAddress,
            messageTransmitterV2RescuerAddress,
            messageTransmitterV2AttesterManagerAddress,
            attesters,
            messageTransmitterV2SignatureThreshold,
            maxMessageBodySize
        );

        // Construct upgrade and initialize data
        bytes memory upgradeAndInitializeData = abi.encodeWithSelector(
            AdminUpgradableProxy.upgradeToAndCall.selector,
            messageTransmitterV2Implementation,
            initializer
        );

        // Construct admin rotation data
        bytes memory adminRotationData = abi.encodeWithSelector(
            AdminUpgradableProxy.changeAdmin.selector,
            messageTransmitterV2AdminAddress
        );

        bytes[] memory multiCallData = new bytes[](2);
        multiCallData[0] = upgradeAndInitializeData;
        multiCallData[1] = adminRotationData;

        // Start recording transactions
        vm.startBroadcast(factoryOwner);

        // Deploy and multicall proxy
        address messageTransmitterV2ProxyAddress = Create2Factory(factory)
            .deployAndMultiCall(
                0,
                SALT_MESSAGE_TRANSMITTER,
                proxyCreateCode,
                multiCallData
            );

        // Stop recording transactions
        vm.stopBroadcast();
        return MessageTransmitterV2(messageTransmitterV2ProxyAddress);
    }

    function deployTokenMessengerV2(
        address factory,
        address factoryOwner
    ) private returns (TokenMessengerV2) {
        // Get proxy creation code
        bytes memory proxyCreateCode = getProxyCreationCode(
            factory,
            factory,
            ""
        );

        // Calculate TokenMessengerV2 proxy address
        address expectedTokenMessengerV2ProxyAddress = vm.computeCreate2Address(
            SALT_TOKEN_MESSENGER,
            keccak256(proxyCreateCode),
            factory
        );

        bool remoteTokenMessengerV2FromEnv = remoteTokenMessengerV2Addresses
            .length > 0;

        // Construct initializer
        bytes32[] memory remoteTokenMessengerAddresses = new bytes32[](
            remoteDomains.length
        );
        uint256 remoteDomainsLength = remoteDomains.length;
        for (uint256 i = 0; i < remoteDomainsLength; ++i) {
            if (remoteTokenMessengerV2FromEnv) {
                remoteTokenMessengerAddresses[
                    i
                ] = remoteTokenMessengerV2Addresses[i];
            } else {
                remoteTokenMessengerAddresses[i] = AddressUtils.toBytes32(
                    expectedTokenMessengerV2ProxyAddress
                );
            }
        }
        bytes memory initializer = abi.encodeWithSelector(
            TokenMessengerV2.initialize.selector,
            tokenMessengerV2OwnerAddress,
            tokenMessengerV2RescuerAddress,
            tokenMessengerV2FeeRecipientAddress,
            tokenMessengerV2DenylisterAddress,
            address(tokenMinterV2),
            remoteDomains,
            remoteTokenMessengerAddresses
        );

        // Construct upgrade and initialize data
        bytes memory upgradeAndInitializeData = abi.encodeWithSelector(
            AdminUpgradableProxy.upgradeToAndCall.selector,
            tokenMessengerV2Implementation,
            initializer
        );

        // Construct admin rotation data
        bytes memory adminRotationData = abi.encodeWithSelector(
            AdminUpgradableProxy.changeAdmin.selector,
            tokenMessengerV2AdminAddress
        );

        bytes[] memory multiCallData = new bytes[](2);
        multiCallData[0] = upgradeAndInitializeData;
        multiCallData[1] = adminRotationData;

        // Start recording transactions
        vm.startBroadcast(factoryOwner);

        // Deploy proxy
        address tokenMessengerV2ProxyAddress = Create2Factory(factory)
            .deployAndMultiCall(
                0,
                SALT_TOKEN_MESSENGER,
                proxyCreateCode,
                multiCallData
            );
        // Stop recording transactions
        vm.stopBroadcast();

        return TokenMessengerV2(tokenMessengerV2ProxyAddress);
    }

    function addMessengerPauserRescuerToTokenMinterV2(
        uint256 tokenMinterV2OwnerPrivateKey,
        uint256 _tokenControllerPrivateKey,
        address tokenMessengerV2Address
    ) private {
        // Start recording transactions
        vm.startBroadcast(tokenMinterV2OwnerPrivateKey);

        if (
            tokenMinterV2.pendingOwner() ==
            vm.addr(tokenMinterV2OwnerPrivateKey)
        ) {
            tokenMinterV2.acceptOwnership();
        }

        tokenMinterV2.addLocalTokenMessenger(tokenMessengerV2Address);
        tokenMinterV2.updatePauser(tokenMinterV2PauserAddress);
        tokenMinterV2.updateRescuer(tokenMinterV2RescuerAddress);

        // Stop recording transactions
        vm.stopBroadcast();

        // Start recording transactions
        vm.startBroadcast(_tokenControllerPrivateKey);

        tokenMinterV2.setMaxBurnAmountPerMessage(
            usdcContractAddress,
            burnLimitPerMessage
        );

        uint256 remoteDomainsLength = remoteDomains.length;
        for (uint256 i = 0; i < remoteDomainsLength; ++i) {
            tokenMinterV2.linkTokenPair(
                usdcContractAddress,
                remoteDomains[i],
                usdcRemoteContractAddresses[i]
            );
        }

        // Stop recording transactions
        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        usdcContractAddress = vm.envAddress("USDC_CONTRACT_ADDRESS");
        bytes32[] memory usdcRemoteContractAddressesMemory = vm.envBytes32(
            "REMOTE_USDC_CONTRACT_ADDRESSES",
            ","
        );
        uint256 usdcRemoteContractAddressesMemoryLength = usdcRemoteContractAddressesMemory
                .length;
        for (uint256 i = 0; i < usdcRemoteContractAddressesMemoryLength; ++i) {
            usdcRemoteContractAddresses.push(
                usdcRemoteContractAddressesMemory[i]
            );
        }
        create2Factory = vm.envAddress("CREATE2_FACTORY_CONTRACT_ADDRESS");

        messageTransmitterV2OwnerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_OWNER_ADDRESS"
        );
        messageTransmitterV2PauserAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_PAUSER_ADDRESS"
        );
        messageTransmitterV2RescuerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_RESCUER_ADDRESS"
        );
        messageTransmitterV2AttesterManagerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_MANAGER_ADDRESS"
        );
        messageTransmitterV2Attester1Address = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_1_ADDRESS"
        );
        messageTransmitterV2Attester2Address = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_2_ADDRESS"
        );
        messageTransmitterV2AdminAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_PROXY_ADMIN_ADDRESS"
        );

        tokenMinterV2PauserAddress = vm.envAddress(
            "TOKEN_MINTER_V2_PAUSER_ADDRESS"
        );
        tokenMinterV2RescuerAddress = vm.envAddress(
            "TOKEN_MINTER_V2_RESCUER_ADDRESS"
        );

        tokenMessengerV2OwnerAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_OWNER_ADDRESS"
        );
        tokenMessengerV2RescuerAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_RESCUER_ADDRESS"
        );
        tokenMessengerV2FeeRecipientAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_FEE_RECIPIENT_ADDRESS"
        );
        tokenMessengerV2DenylisterAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_DENYLISTER_ADDRESS"
        );
        tokenMessengerV2AdminAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_PROXY_ADMIN_ADDRESS"
        );

        domain = uint32(vm.envUint("DOMAIN"));
        version = uint32(vm.envUint("VERSION"));
        messageBodyVersion = uint32(vm.envUint("MESSAGE_BODY_VERSION"));

        uint256[] memory remoteDomainsUint256 = vm.envUint(
            "REMOTE_DOMAINS",
            ","
        );
        uint256 remoteDomainsUint256Length = remoteDomainsUint256.length;
        for (uint256 i = 0; i < remoteDomainsUint256Length; ++i) {
            remoteDomains.push(uint32(remoteDomainsUint256[i]));
        }
        burnLimitPerMessage = vm.envUint("BURN_LIMIT_PER_MESSAGE");

        create2FactoryOwner = vm.envAddress("CREATE2_FACTORY_OWNER");
        tokenMinterV2OwnerPrivateKey = vm.envUint("TOKEN_MINTER_V2_OWNER_KEY");
        tokenControllerPrivateKey = vm.envUint("TOKEN_CONTROLLER_KEY");

        bytes32[] memory emptyRemoteTokenMessengerV2Addresses = new bytes32[](
            0
        );
        remoteTokenMessengerV2Addresses = vm.envOr(
            "REMOTE_TOKEN_MESSENGER_V2_ADDRESSES",
            ",",
            emptyRemoteTokenMessengerV2Addresses
        );

        // Predict other addresses needed
        messageTransmitterV2Implementation = predictDeployments
            .messageTransmitterV2Impl(create2Factory, domain, version);
        tokenMinterV2 = TokenMinterV2(
            predictDeployments.tokenMinterV2(create2Factory)
        );
        tokenMessengerV2Implementation = predictDeployments
            .tokenMessengerV2Impl(create2Factory, messageBodyVersion);
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        messageTransmitterV2 = deployMessageTransmitterV2(
            create2Factory,
            create2FactoryOwner
        );

        tokenMessengerV2 = deployTokenMessengerV2(
            create2Factory,
            create2FactoryOwner
        );

        addMessengerPauserRescuerToTokenMinterV2(
            tokenMinterV2OwnerPrivateKey,
            tokenControllerPrivateKey,
            address(tokenMessengerV2)
        );
    }

    /**
     * @notice Alternate, standalone entrypoint to configure the TokenMinterV2
     */
    function configureTokenMinterV2() public {
        addMessengerPauserRescuerToTokenMinterV2(
            tokenMinterV2OwnerPrivateKey,
            tokenControllerPrivateKey,
            predictDeployments.tokenMessengerV2Proxy(create2Factory)
        );
    }
}
