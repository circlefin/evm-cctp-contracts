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

import {Test} from "forge-std/Test.sol";
import {MessageV2} from "../../../src/messages/v2/MessageV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";

contract MessageV2Test is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using MessageV2 for bytes29;

    function testFormatMessage(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public view {
        bytes memory _message = MessageV2._formatMessageForRelay(
            _version,
            _sourceDomain,
            _destinationDomain,
            _sender,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );

        bytes29 _m = _message.ref(0);
        assertEq(uint256(_m._getVersion()), uint256(_version));
        assertEq(uint256(_m._getSourceDomain()), uint256(_sourceDomain));
        assertEq(
            uint256(_m._getDestinationDomain()),
            uint256(_destinationDomain)
        );

        assertEq(_m._getNonce(), bytes32(0));
        assertEq(_m._getSender(), _sender);
        assertEq(_m._getRecipient(), _recipient);
        assertEq(_m._getDestinationCaller(), _destinationCaller);
        assertEq(
            uint256(_m._getMinFinalityThreshold()),
            uint256(_minFinalityThreshold)
        );
        assertEq(uint256(_m._getFinalityThresholdExecuted()), uint256(0));
        assertEq(_m._getMessageBody().clone(), _messageBody);
    }

    function testIsValidMessage_revertsForEmptyMessage() public {
        bytes29 _m = TypedMemView.nullView();
        vm.expectRevert("Malformed message");
        MessageV2._validateMessageFormat(_m);
    }

    function testIsValidMessage_revertsForTooShortMessage(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public {
        bytes memory _message = MessageV2._formatMessageForRelay(
            _version,
            _sourceDomain,
            _destinationDomain,
            _sender,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
        bytes29 _m = _message.ref(0);

        // Lop off the _messageBody bytes, and then one more
        _m = _m.slice(0, _m.len() - _messageBody.length - 1, 0);

        vm.expectRevert("Invalid message: too short");
        MessageV2._validateMessageFormat(_m);
    }
}
