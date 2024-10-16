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

import {MessageTransmitterV2} from "../../../src/v2/MessageTransmitterV2.sol";

contract MockMessageTransmitterV3 is MessageTransmitterV2 {
    address public newV3State;

    constructor(
        uint32 _localDomain,
        uint32 _version
    ) MessageTransmitterV2(_localDomain, _version) {}

    function initializeV3(address newState) external reinitializer(2) {
        newV3State = newState;
    }

    function v3Function() external pure returns (bool) {
        return true;
    }
}
