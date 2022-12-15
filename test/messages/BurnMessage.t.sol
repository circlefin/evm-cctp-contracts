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

import "@memview-sol/contracts/TypedMemView.sol";
import "forge-std/Test.sol";
import "../../src/messages/BurnMessage.sol";
import "../../src/messages/Message.sol";

contract BurnMessageTest is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessage for bytes29;

    uint32 version = 1;

    function testFormatMessage_succeeds(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        address msgSender
    ) public {
        bytes memory _expectedMessageBody = abi.encodePacked(
            version,
            _burnToken,
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msgSender)
        );

        bytes memory _messageBody = BurnMessage._formatMessage(
            version,
            _burnToken,
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msgSender)
        );

        bytes29 _m = _messageBody.ref(0);
        assertEq(_m._getMintRecipient(), _mintRecipient);
        assertEq(_m._getBurnToken(), _burnToken);
        assertEq(_m._getAmount(), _amount);
        assertEq(uint256(_m._getVersion()), uint256(version));
        assertEq(_m._getMessageSender(), Message.addressToBytes32(msgSender));
        _m._validateBurnMessageFormat();

        assertEq(_expectedMessageBody.ref(0).keccak(), _m.keccak());
    }

    function testIsValidBurnMessage_returnsFalseForTooShortMessage(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount
    ) public {
        bytes memory _messageBody = BurnMessage._formatMessage(
            version,
            _burnToken,
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msg.sender)
        );

        bytes29 _m = _messageBody.ref(0);
        _m = _m.slice(0, _m.len() - 1, 0);

        vm.expectRevert("Invalid message length");
        _m._validateBurnMessageFormat();
    }

    function testIsValidBurnMessage_revertsForTooLongMessage(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        address msgSender
    ) public {
        bytes memory _tooLongMessageBody = abi.encodePacked(
            version,
            _burnToken,
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msgSender),
            _amount // encode _amount twice (invalid)
        );

        bytes29 _m = _tooLongMessageBody.ref(0);
        assertEq(_m._getMintRecipient(), _mintRecipient);
        assertEq(_m._getBurnToken(), _burnToken);
        assertEq(_m._getAmount(), _amount);
        vm.expectRevert("Invalid message length");
        _m._validateBurnMessageFormat();
    }

    function testIsValidBurnMessage_revertsForMalformedMessage() public {
        bytes29 _m = TypedMemView.nullView();
        vm.expectRevert("Malformed message");
        BurnMessage._validateBurnMessageFormat(_m);
    }
}
