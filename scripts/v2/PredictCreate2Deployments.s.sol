/*
 * Copyright 2025 Circle Internet Group, Inc. All rights reserved.
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
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {AddressUtilsExternal} from "../../src/messages/v2/AddressUtilsExternal.sol";
import {SALT_MESSAGE_TRANSMITTER, SALT_TOKEN_MESSENGER, SALT_TOKEN_MINTER, SALT_ADDRESS_UTILS_EXTERNAL} from "./Salts.sol";

contract PredictCreate2Deployments is Script {
    function messageTransmitterV2Proxy(
        address create2Factory
    ) public returns (address) {
        return
            vm.computeCreate2Address(
                SALT_MESSAGE_TRANSMITTER,
                keccak256(
                    abi.encodePacked(
                        type(AdminUpgradableProxy).creationCode,
                        abi.encode(create2Factory, create2Factory, "")
                    )
                ),
                create2Factory
            );
    }

    function messageTransmitterV2Impl(
        address create2Factory,
        uint32 domain,
        uint32 version
    ) public returns (address) {
        return
            vm.computeCreate2Address(
                SALT_MESSAGE_TRANSMITTER,
                keccak256(
                    abi.encodePacked(
                        type(MessageTransmitterV2).creationCode,
                        abi.encode(domain, version)
                    )
                ),
                create2Factory
            );
    }

    function tokenMessengerV2Proxy(
        address create2Factory
    ) public returns (address) {
        return
            vm.computeCreate2Address(
                SALT_TOKEN_MESSENGER,
                keccak256(
                    abi.encodePacked(
                        type(AdminUpgradableProxy).creationCode,
                        abi.encode(create2Factory, create2Factory, "")
                    )
                ),
                create2Factory
            );
    }

    function tokenMessengerV2Impl(
        address create2Factory,
        uint32 messageBodyVersion
    ) public returns (address) {
        address _messageTransmitterProxy = messageTransmitterV2Proxy(
            create2Factory
        );
        return
            vm.computeCreate2Address(
                SALT_TOKEN_MESSENGER,
                keccak256(
                    abi.encodePacked(
                        type(TokenMessengerV2).creationCode,
                        abi.encode(_messageTransmitterProxy, messageBodyVersion)
                    )
                ),
                create2Factory
            );
    }

    function tokenMinterV2(address create2Factory) public returns (address) {
        return
            vm.computeCreate2Address(
                SALT_TOKEN_MINTER,
                keccak256(
                    abi.encodePacked(
                        type(TokenMinterV2).creationCode,
                        abi.encode(create2Factory)
                    )
                ),
                create2Factory
            );
    }

    function addressUtilsExternal(
        address create2Factory
    ) public returns (address) {
        return
            vm.computeCreate2Address(
                SALT_ADDRESS_UTILS_EXTERNAL,
                keccak256(
                    abi.encodePacked(type(AddressUtilsExternal).creationCode)
                ),
                create2Factory
            );
    }
}
