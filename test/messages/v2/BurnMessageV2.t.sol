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

import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {Test} from "forge-std/Test.sol";
import {BurnMessageV2} from "../../../src/messages/v2/BurnMessageV2.sol";

contract BurnMessageV2Test is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;

    function testFormatMessageyForRelay_succeeds(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _messageSender,
        uint256 _maxFee,
        bytes calldata _hookData
    ) public view {
        bytes memory _expectedMessageBody = abi.encodePacked(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _messageSender,
            _maxFee,
            uint256(0),
            uint256(0),
            _hookData
        );

        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _messageSender,
            _maxFee,
            _hookData
        );

        bytes29 _m = _messageBody.ref(0);
        assertEq(uint256(_m._getVersion()), uint256(_version));
        assertEq(_m._getBurnToken(), _burnToken);
        assertEq(_m._getMintRecipient(), _mintRecipient);
        assertEq(_m._getAmount(), _amount);
        assertEq(_m._getMessageSender(), _messageSender);
        assertEq(_m._getMaxFee(), _maxFee);
        assertEq(_m._getFeeExecuted(), 0);
        assertEq(_m._getExpirationBlock(), 0);
        assertEq(_m._getHookData().clone(), _hookData);

        _m._validateBurnMessageFormat();

        assertEq(_expectedMessageBody.ref(0).keccak(), _m.keccak());
    }

    function testIsValidBurnMessage_revertsForTooShortMessage(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _messageSender,
        uint256 _maxFee,
        bytes calldata _hookData
    ) public {
        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _messageSender,
            _maxFee,
            _hookData
        );
        bytes29 _m = _messageBody.ref(0);

        // Lop off the hookData bytes, and then one more
        _m = _m.slice(0, _m.len() - _hookData.length - 1, 0);

        vm.expectRevert("Invalid burn message: too short");
        _m._validateBurnMessageFormat();
    }

    function testIsValidBurnMessage_revertsForEmptyMessage() public {
        bytes29 _m = TypedMemView.nullView();
        vm.expectRevert("Malformed message");
        BurnMessageV2._validateBurnMessageFormat(_m);
    }
}
