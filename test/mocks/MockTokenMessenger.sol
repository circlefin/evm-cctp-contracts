/*
 * Copyright (c) 2022, Circle Internet Financial Limited.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

import "../../src/interfaces/IMessageHandler.sol";

contract MockTokenMessenger is IMessageHandler {
    // ============ Constructor ============
    constructor() {}

    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 _sender,
        bytes memory _messageBody
    ) external override returns (bool) {
        // revert if _messageBody is 'revert', otherwise do nothing
        require(
            keccak256(_messageBody) != keccak256(bytes("revert")),
            "mock revert"
        );

        if (keccak256(_messageBody) == keccak256(bytes("return false"))) {
            return false;
        }

        return true;
    }
}
