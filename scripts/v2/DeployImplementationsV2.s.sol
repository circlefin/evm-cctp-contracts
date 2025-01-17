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
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {Create2Factory} from "../../src/v2/Create2Factory.sol";
import {Ownable2Step} from "../../src/roles/Ownable2Step.sol";
import {SALT_MESSAGE_TRANSMITTER, SALT_TOKEN_MESSENGER, SALT_TOKEN_MINTER} from "./Salts.sol";

contract DeployImplementationsV2Script is Script {
    // Expose for tests
    MessageTransmitterV2 public messageTransmitterV2;
    TokenMessengerV2 public tokenMessengerV2;
    TokenMinterV2 public tokenMinterV2;
    address public expectedMessageTransmitterV2ProxyAddress;

    address private factoryAddress;
    address private tokenMinterOwnerAddress;
    uint256 private tokenMinterOwnerKey;
    address private tokenControllerAddress;
    uint32 private messageBodyVersion;
    uint32 private version;
    uint32 private domain;
    uint256 private create2FactoryOwnerPrivateKey;

    function deployImplementationsV2()
        private
        returns (MessageTransmitterV2, TokenMinterV2, TokenMessengerV2)
    {
        // Calculate MessageTransmitterV2 proxy address
        expectedMessageTransmitterV2ProxyAddress = vm.computeCreate2Address(
            SALT_MESSAGE_TRANSMITTER,
            keccak256(
                abi.encodePacked(
                    type(AdminUpgradableProxy).creationCode,
                    abi.encode(factoryAddress, factoryAddress, "")
                )
            ),
            factoryAddress
        );

        Create2Factory factory = Create2Factory(factoryAddress);

        // Start recording transactions
        vm.startBroadcast(create2FactoryOwnerPrivateKey);

        // Deploy MessageTransmitterV2 implementation
        messageTransmitterV2 = MessageTransmitterV2(
            factory.deploy(
                0,
                SALT_MESSAGE_TRANSMITTER,
                abi.encodePacked(
                    type(MessageTransmitterV2).creationCode,
                    abi.encode(domain, version)
                )
            )
        );

        // Deploy TokenMessengerV2 implementation
        tokenMessengerV2 = TokenMessengerV2(
            factory.deploy(
                0,
                SALT_TOKEN_MESSENGER,
                abi.encodePacked(
                    type(TokenMessengerV2).creationCode,
                    abi.encode(
                        expectedMessageTransmitterV2ProxyAddress,
                        messageBodyVersion
                    )
                )
            )
        );

        // Since the TokenMinter sets the msg.sender of the deployment to be
        // the Owner, we'll need to rotate it from the Create2Factory atomically.
        bytes memory tokenMinterOwnershipRotation = abi.encodeWithSelector(
            Ownable2Step.transferOwnership.selector,
            tokenMinterOwnerAddress
        );
        bytes[] memory tokenMinterMultiCallData = new bytes[](1);
        tokenMinterMultiCallData[0] = tokenMinterOwnershipRotation;

        // Deploy TokenMinter
        tokenMinterV2 = TokenMinterV2(
            factory.deployAndMultiCall(
                0,
                SALT_TOKEN_MINTER,
                abi.encodePacked(
                    type(TokenMinterV2).creationCode,
                    abi.encode(tokenControllerAddress)
                ),
                tokenMinterMultiCallData
            )
        );

        // Stop recording transactions
        vm.stopBroadcast();

        // Accept the TokenMinter 2-step ownership
        vm.startBroadcast(tokenMinterOwnerKey);
        tokenMinterV2.acceptOwnership();
        vm.stopBroadcast();

        return (messageTransmitterV2, tokenMinterV2, tokenMessengerV2);
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        factoryAddress = vm.envAddress("CREATE2_FACTORY_CONTRACT_ADDRESS");
        create2FactoryOwnerPrivateKey = vm.envUint("CREATE2_FACTORY_OWNER_KEY");
        tokenMinterOwnerAddress = vm.envAddress(
            "TOKEN_MINTER_V2_OWNER_ADDRESS"
        );
        tokenMinterOwnerKey = vm.envUint("TOKEN_MINTER_V2_OWNER_KEY");
        tokenControllerAddress = vm.envAddress("TOKEN_CONTROLLER_ADDRESS");
        domain = uint32(vm.envUint("DOMAIN"));
        messageBodyVersion = uint32(vm.envUint("MESSAGE_BODY_VERSION"));
        version = uint32(vm.envUint("VERSION"));
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        (
            messageTransmitterV2,
            tokenMinterV2,
            tokenMessengerV2
        ) = deployImplementationsV2();
    }
}
