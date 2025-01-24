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

import {IMessageHandlerV2} from "../../../src/interfaces/v2/IMessageHandlerV2.sol";
import {MockReentrantCaller} from "../MockReentrantCaller.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract MockReentrantCallerV2 is IMessageHandlerV2, MockReentrantCaller {
    function handleReceiveFinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32,
        bytes calldata messageBody
    ) external override returns (bool) {
        return handleReceiveMessage(sourceDomain, sender, messageBody);
    }

    function handleReceiveUnfinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32,
        bytes calldata messageBody
    ) external override returns (bool) {
        return handleReceiveMessage(sourceDomain, sender, messageBody);
    }
}
