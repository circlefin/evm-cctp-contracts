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

import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {Test} from "forge-std/Test.sol";
import {BurnMessageV2} from "../../../src/messages/v2/BurnMessageV2.sol";

contract BurnMessageV2Test is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;

    function testFormatMessage_succeeds(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _messageSender,
        uint256 _feeRequested,
        bytes calldata _hook
    ) public {
        bytes memory _expectedMessageBody = abi.encodePacked(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _messageSender,
            _feeRequested,
            _hook
        );

        bytes memory _messageBody = BurnMessageV2._formatMessage(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _messageSender,
            _feeRequested,
            _hook
        );

        bytes29 _m = _messageBody.ref(0);
        assertEq(_expectedMessageBody.ref(0).keccak(), _m.keccak());
    }
}
