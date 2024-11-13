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

import "forge-std/Script.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";

contract RotateKeysV2Script is Script {
    address private messageTransmitterV2ContractAddress;
    address private tokenMessengerV2ContractAddress;
    address private tokenMinterV2ContractAddress;
    address private newTokenControllerAddress;

    uint256 private messageTransmitterV2OwnerPrivateKey;
    uint256 private tokenMessengerV2OwnerPrivateKey;
    uint256 private tokenMinterV2OwnerPrivateKey;

    address private messageTransmitterV2NewOwnerAddress;
    address private tokenMessengerV2NewOwnerAddress;
    address private tokenMinterV2NewOwnerAddress;

    function rotateMessageTransmitterV2Owner(uint256 privateKey) public {
        // load messageTransmitter
        MessageTransmitterV2 messageTransmitterV2 = MessageTransmitterV2(
            messageTransmitterV2ContractAddress
        );

        vm.startBroadcast(privateKey);

        messageTransmitterV2.transferOwnership(
            messageTransmitterV2NewOwnerAddress
        );

        vm.stopBroadcast();
    }

    function rotateTokenMessengerV2Owner(uint256 privateKey) public {
        TokenMessengerV2 tokenMessengerV2 = TokenMessengerV2(
            tokenMessengerV2ContractAddress
        );

        vm.startBroadcast(privateKey);

        tokenMessengerV2.transferOwnership(tokenMessengerV2NewOwnerAddress);

        vm.stopBroadcast();
    }

    function rotateTokenControllerThenTokenMinterV2Owner(
        uint256 privateKey
    ) public {
        TokenMinterV2 tokenMinterV2 = TokenMinterV2(
            tokenMinterV2ContractAddress
        );

        vm.startBroadcast(privateKey);

        tokenMinterV2.setTokenController(newTokenControllerAddress);

        tokenMinterV2.transferOwnership(tokenMinterV2NewOwnerAddress);

        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        messageTransmitterV2ContractAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_CONTRACT_ADDRESS"
        );

        tokenMessengerV2ContractAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_CONTRACT_ADDRESS"
        );

        tokenMinterV2ContractAddress = vm.envAddress(
            "TOKEN_MINTER_V2_CONTRACT_ADDRESS"
        );

        messageTransmitterV2OwnerPrivateKey = vm.envUint(
            "MESSAGE_TRANSMITTER_V2_OWNER_KEY"
        );
        tokenMessengerV2OwnerPrivateKey = vm.envUint(
            "TOKEN_MESSENGER_V2_OWNER_KEY"
        );
        tokenMinterV2OwnerPrivateKey = vm.envUint("TOKEN_MINTER_V2_OWNER_KEY");

        messageTransmitterV2NewOwnerAddress = vm.envAddress(
            "MESSAGE_TRANSMITTER_V2_NEW_OWNER_ADDRESS"
        );

        tokenMessengerV2NewOwnerAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_NEW_OWNER_ADDRESS"
        );

        tokenMinterV2NewOwnerAddress = vm.envAddress(
            "TOKEN_MINTER_V2_NEW_OWNER_ADDRESS"
        );

        newTokenControllerAddress = vm.envAddress(
            "NEW_TOKEN_CONTROLLER_ADDRESS"
        );
    }

    /**
     * @notice main function that will be run by forge
     */
    function run() public {
        rotateMessageTransmitterV2Owner(messageTransmitterV2OwnerPrivateKey);
        rotateTokenMessengerV2Owner(tokenMessengerV2OwnerPrivateKey);
        rotateTokenControllerThenTokenMinterV2Owner(
            tokenMinterV2OwnerPrivateKey
        );
    }
}
