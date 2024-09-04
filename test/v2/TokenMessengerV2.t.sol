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

import {BaseTokenMessengerTest} from "./BaseTokenMessenger.t.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";

contract TokenMessengerV2Test is BaseTokenMessengerTest {
    // Constants
    uint32 messageBodyVersion = 2;
    address localMessageTransmitter = address(10);

    TokenMessengerV2 tokenMessenger;

    function setUp() public override {
        tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        super.setUp();
    }

    function setUpBaseTokenMessenger()
        internal
        view
        override
        returns (address)
    {
        return address(tokenMessenger);
    }

    function createBaseTokenMessenger(
        address _localMessageTransmitter,
        uint32 _messageBodyVersion
    ) internal override returns (address) {
        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            _localMessageTransmitter,
            _messageBodyVersion
        );
        return address(_tokenMessenger);
    }
}
