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
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {Message} from "../../src/messages/Message.sol";

contract SetupRemoteResourcesV2Script is Script {
    address private usdcRemoteContractAddress;
    address private usdcContractAddress;
    address private tokenMessengerV2ContractAddress;
    address private tokenMinterV2ContractAddress;

    uint32 private remoteDomain;

    uint256 private tokenMessengerV2OwnerPrivateKey;
    uint256 private tokenControllerPrivateKey;

    /**
     * @notice link current chain and remote chain tokens
     */
    function linkTokenPairV2(
        TokenMinterV2 tokenMinterV2,
        uint256 privateKey
    ) private {
        // Start recording transactions
        vm.startBroadcast(privateKey);

        bytes32 remoteUsdcContractAddressInBytes32 = Message.addressToBytes32(
            usdcRemoteContractAddress
        );

        tokenMinterV2.linkTokenPair(
            usdcContractAddress,
            remoteDomain,
            remoteUsdcContractAddressInBytes32
        );

        // Stop recording transactions
        vm.stopBroadcast();
    }

    /**
     * @notice add address of TokenMessenger deployed on another chain
     */
    function addRemoteTokenMessengerV2(
        TokenMessengerV2 tokenMessengerV2,
        uint256 privateKey
    ) private {
        // Start recording transactions
        vm.startBroadcast(privateKey);
        bytes32 remoteTokenMessengerAddressInBytes32 = Message.addressToBytes32(
            address(tokenMessengerV2)
        );
        tokenMessengerV2.addRemoteTokenMessenger(
            remoteDomain,
            remoteTokenMessengerAddressInBytes32
        );

        // Stop recording transactions
        vm.stopBroadcast();
    }

    /**
     * @notice initialize variables from environment
     */
    function setUp() public {
        tokenMessengerV2OwnerPrivateKey = vm.envUint(
            "TOKEN_MESSENGER_V2_OWNER_KEY"
        );
        tokenControllerPrivateKey = vm.envUint("TOKEN_CONTROLLER_KEY");

        tokenMessengerV2ContractAddress = vm.envAddress(
            "TOKEN_MESSENGER_V2_CONTRACT_ADDRESS"
        );
        tokenMinterV2ContractAddress = vm.envAddress(
            "TOKEN_MINTER_V2_CONTRACT_ADDRESS"
        );
        usdcContractAddress = vm.envAddress("USDC_CONTRACT_ADDRESS");
        usdcRemoteContractAddress = vm.envAddress(
            "REMOTE_USDC_CONTRACT_ADDRESS"
        );

        remoteDomain = uint32(vm.envUint("REMOTE_DOMAIN"));
    }

    /**
     * @notice main function that will be run by forge
     *         this links the remote usdc token and the remote token messenger
     */
    function run() public {
        TokenMessengerV2 tokenMessengerV2 = TokenMessengerV2(
            tokenMessengerV2ContractAddress
        );
        TokenMinterV2 tokenMinterV2 = TokenMinterV2(
            tokenMinterV2ContractAddress
        );

        // Link token pair and add remote token messenger
        linkTokenPairV2(tokenMinterV2, tokenControllerPrivateKey);
        addRemoteTokenMessengerV2(
            tokenMessengerV2,
            tokenMessengerV2OwnerPrivateKey
        );
    }
}
