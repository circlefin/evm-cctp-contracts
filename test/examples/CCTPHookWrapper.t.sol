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

import {CCTPHookWrapper} from "../../src/examples/CCTPHookWrapper.sol";
import {IReceiver} from "../../src/interfaces/v2/IReceiverV2.sol";
import {MessageV2} from "../../src/messages/v2/MessageV2.sol";
import {BurnMessageV2} from "../../src/messages/v2/BurnMessageV2.sol";
import {MockHookTarget} from "../mocks/v2/MockHookTarget.sol";
import {Test} from "forge-std/Test.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";

contract CCTPHookWrapperTest is Test {
    // Libraries

    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // Test events
    event HookReceived(uint256 paramOne, uint256 paramTwo);

    // Test constants

    uint32 v2MessageVersion = 1;
    uint32 v2MessageBodyVersion = 1;

    address wrapperOwner = address(123);

    address localMessageTransmitter = address(10);
    MockHookTarget hookTarget;
    CCTPHookWrapper wrapper;

    function setUp() public {
        vm.prank(wrapperOwner);
        wrapper = new CCTPHookWrapper(localMessageTransmitter);

        hookTarget = new MockHookTarget();
    }

    // Tests

    function testInitialization__revertsIfMessageTransmitterIsZero() public {
        vm.expectRevert("Message transmitter is the zero address");
        new CCTPHookWrapper(address(0));
    }

    function testInitialization__setsTheMessageTransmitter(
        address _messageTransmitter
    ) public {
        vm.assume(_messageTransmitter != address(0));
        CCTPHookWrapper _wrapper = new CCTPHookWrapper(_messageTransmitter);
        assertEq(address(_wrapper.messageTransmitter()), _messageTransmitter);
    }

    function testInitialization__usesTheV2MessageVersion() public view {
        assertEq(
            uint256(address(wrapper.supportedMessageVersion())),
            uint256(v2MessageVersion)
        );
    }

    function testInitialization__usesTheV2MessageBodyVersion() public view {
        assertEq(
            uint256(address(wrapper.supportedMessageBodyVersion())),
            uint256(v2MessageBodyVersion)
        );
    }

    function testRelay__revertsIfNotCalledByOwner(
        address _randomAddress,
        bytes calldata _randomBytes
    ) public {
        vm.assume(_randomAddress != wrapperOwner);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_randomAddress);
        wrapper.relay(_randomBytes, bytes(""));
    }

    function testRelay__revertsIfMessageFormatVersionIsInvalid(
        uint32 _messageVersion
    ) public {
        vm.assume(_messageVersion != v2MessageVersion);

        vm.expectRevert("Invalid message version");
        bytes memory _message = _createMessage(
            _messageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        vm.prank(wrapperOwner);
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageBodyVersionIsInvalid(
        uint32 _messageBodyVersion
    ) public {
        vm.assume(_messageBodyVersion != v2MessageBodyVersion);

        vm.expectRevert("Invalid message body version");
        bytes memory _message = _createMessage(
            v2MessageVersion,
            _messageBodyVersion,
            bytes("")
        );

        vm.prank(wrapperOwner);
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageValidationFails() public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        // Slice the message to make it fail validation
        bytes memory _truncatedMessage = _message
            .ref(0)
            .slice(0, 147, 0)
            .clone(); // See: MessageV2#MESSAGE_BODY_INDEX

        vm.expectRevert("Invalid message: too short");

        vm.prank(wrapperOwner);
        wrapper.relay(_truncatedMessage, bytes(""));
    }

    function testRelay__revertsIfMessageBodyValidationFails() public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        // Slice the message to make it fail validation
        bytes memory _truncatedMessage = _message
            .ref(0)
            .slice(0, 375, 0)
            .clone(); // See: BurnMessageV2#HOOK_DATA_INDEX (148 + 228 = 376)

        vm.expectRevert("Invalid burn message: too short");

        vm.prank(wrapperOwner);
        wrapper.relay(_truncatedMessage, bytes(""));
    }

    function testRelay__revertsIfMessageTransmitterCallReverts() public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        // Mock a reverting call to message transmitter
        vm.mockCallRevert(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            "Testing: message transmitter failed"
        );

        vm.expectRevert();

        vm.prank(wrapperOwner);
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageTransmitterReturnsFalse() public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        // Mock receiveMessage() returning false
        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(false)
        );

        vm.expectCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            1
        );

        vm.expectRevert("Receive message failed");

        vm.prank(wrapperOwner);
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__succeedsWithNoHook() public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            bytes("")
        );

        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(true)
        );

        vm.prank(wrapperOwner);
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertFalse(_hookSuccess);
        assertEq(_returnData.length, 0);
    }

    function testRelay__succeedsWithFailingHook() public {
        // Prepare a message with hookCalldata that will fail
        bytes memory _failingHookCalldata = abi.encodeWithSelector(
            MockHookTarget.failingHook.selector
        );
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            abi.encodePacked(address(hookTarget), _failingHookCalldata)
        );

        // Mock successful call to MessageTransmitter
        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(true)
        );

        // Call wrapper
        vm.prank(wrapperOwner);
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertFalse(_hookSuccess);
        assertEq(_getRevertMsg(_returnData), "Hook failure");
    }

    function testRelay__succeedsAndIgnoresHooksLessThanRequiredLength(
        bytes calldata randomBytes
    ) public {
        vm.assume(randomBytes.length > 20);
        // Prepare a message with hookData less than required length (20 bytes)
        bytes memory _shortCallData = randomBytes[:19];
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            _shortCallData
        );

        // Mock successful call to MessageTransmitter
        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(true)
        );

        // Call wrapper
        vm.prank(wrapperOwner);
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertFalse(_hookSuccess);
        assertEq(_returnData.length, 0);
    }

    function testRelay__succeedsWithCallToEOAHookTarget(
        bytes calldata _hookCalldata
    ) public {
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            abi.encodePacked(address(12345), _hookCalldata)
        );

        // Mock successful call to MessageTransmitter
        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(true)
        );

        // Call wrapper
        vm.prank(wrapperOwner);
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertTrue(_hookSuccess);
        assertEq(_returnData.length, 0);
    }

    function testRelay__succeedsWithSucceedingHook() public {
        // Prepare a message with hookCalldata that will succeed
        uint256 _expectedReturnData = 12;
        bytes memory _succeedingHookCallData = abi.encodeWithSelector(
            MockHookTarget.succeedingHook.selector,
            5,
            7
        );
        bytes memory _message = _createMessage(
            v2MessageVersion,
            v2MessageBodyVersion,
            abi.encodePacked(address(hookTarget), _succeedingHookCallData)
        );

        // Mock successful call to MessageTransmitter
        vm.mockCall(
            localMessageTransmitter,
            abi.encodeWithSelector(
                IReceiver.receiveMessage.selector,
                _message,
                bytes("")
            ),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit HookReceived(5, 7);

        // Call wrapper
        vm.prank(wrapperOwner);
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertTrue(_hookSuccess);
        assertEq(abi.decode(_returnData, (uint256)), _expectedReturnData);
    }

    // Test Utils

    function _createMessage(
        uint32 _messageVersion,
        uint32 _messageBodyVersion,
        bytes memory _hookData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _messageVersion, // messageVersion
                uint32(0), // sourceDomain
                uint32(0), // destinationDomain
                bytes32(0), // nonce
                bytes32(0), // sender
                bytes32(0), // recipient
                bytes32(0), // destinationCaller
                uint32(0), // minFinalityThreshold
                uint32(0), // finalityThresholdExecuted
                _createBurnMessage(_messageBodyVersion, _hookData)
            );
    }

    function _createBurnMessage(
        uint32 _burnMessageVersion,
        bytes memory _hookData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _burnMessageVersion, // messageBodyVersion
                bytes32(0), // burnToken
                bytes32(0), // mintRecipient
                uint256(0), // amount
                bytes32(0), // messageSender
                uint256(0), // maxFee
                uint256(0), // feeExecuted
                uint256(0), // expirationBlock
                _hookData // hookData
            );
    }

    // source: https://ethereum.stackexchange.com/a/83577
    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
