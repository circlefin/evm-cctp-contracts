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

import {Script} from "forge-std/Script.sol";
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";

contract DeployImplementationsV2Script is Script {
    // Expose for tests
    MessageTransmitterV2 public messageTransmitterV2;
    TokenMessengerV2 public tokenMessengerV2;
    TokenMinterV2 public tokenMinterV2;
    address public expectedMessageTransmitterV2ProxyAddress;

    address private factoryAddress;
    address private tokenControllerAddress;
    uint32 private messageBodyVersion;
    uint32 private version;
    uint32 private domain;
    uint256 private implementationDeployerPrivateKey;

    function deployImplementationsV2(
        uint256 privateKey
    ) private returns (MessageTransmitterV2, TokenMinterV2, TokenMessengerV2) {
        // Calculate MessageTransmitterV2 proxy address
        expectedMessageTransmitterV2ProxyAddress = vm.computeCreate2Address(
            keccak256(type(MessageTransmitterV2).creationCode),
            keccak256(
                abi.encodePacked(
                    type(AdminUpgradableProxy).creationCode,
                    abi.encode(factoryAddress, factoryAddress, "")
                )
            ),
            factoryAddress
        );

        // Start recording transactions
        vm.startBroadcast(privateKey);

        // Deploy MessageTransmitterV2 implementation
        MessageTransmitterV2 messageTransmitterV2Implementation = new MessageTransmitterV2(
                domain,
                version
            );

        // Deploy TokenMinter
        TokenMinterV2 tokenMinterV2Implementation = new TokenMinterV2(
            tokenControllerAddress
        );

        // Deploy TokenMessengerV2
        TokenMessengerV2 tokenMessengerV2Implementation = new TokenMessengerV2(
            expectedMessageTransmitterV2ProxyAddress,
            messageBodyVersion
        );

        // Stop recording transactions
        vm.stopBroadcast();
        return (
            messageTransmitterV2Implementation,
            tokenMinterV2Implementation,
            tokenMessengerV2Implementation
        );
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        factoryAddress = vm.envAddress("CREATE2_FACTORY_CONTRACT_ADDRESS");
        tokenControllerAddress = vm.envAddress("TOKEN_CONTROLLER_ADDRESS");
        domain = uint32(vm.envUint("DOMAIN"));
        messageBodyVersion = uint32(vm.envUint("MESSAGE_BODY_VERSION"));
        version = uint32(vm.envUint("VERSION"));
        implementationDeployerPrivateKey = vm.envUint(
            "IMPLEMENTATION_DEPLOYER_PRIVATE_KEY"
        );
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        (
            messageTransmitterV2,
            tokenMinterV2,
            tokenMessengerV2
        ) = deployImplementationsV2(implementationDeployerPrivateKey);
    }
}
