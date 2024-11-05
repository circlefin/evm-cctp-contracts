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

contract CCTPHookWrapperTest is Test {
    // Test events
    event HookReceived(uint256 paramOne, uint256 paramTwo);

    // Test constants

    uint32 messageVersion = 1;
    uint32 messageBodyVersion = 1;

    address localMessageTransmitter = address(10);
    MockHookTarget hookTarget;
    CCTPHookWrapper wrapper;

    function setUp() public {
        wrapper = new CCTPHookWrapper(
            localMessageTransmitter,
            messageVersion,
            messageBodyVersion
        );
        hookTarget = new MockHookTarget();
    }

    // Tests

    function testInitialization__revertsIfMessageTransmitterIsZero() public {
        vm.expectRevert("Message transmitter is the zero address");
        new CCTPHookWrapper(address(0), messageVersion, messageBodyVersion);
    }

    function testInitialization__setsTheMessageTransmitter(
        address _messageTransmitter
    ) public {
        vm.assume(_messageTransmitter != address(0));
        CCTPHookWrapper _wrapper = new CCTPHookWrapper(
            _messageTransmitter,
            messageVersion,
            messageBodyVersion
        );
        assertEq(address(_wrapper.messageTransmitter()), _messageTransmitter);
    }

    function testInitialization__setsTheMessageVersion(
        uint32 _messageVersion
    ) public {
        CCTPHookWrapper _wrapper = new CCTPHookWrapper(
            localMessageTransmitter,
            _messageVersion,
            messageBodyVersion
        );
        assertEq(
            uint256(address(_wrapper.supportedMessageVersion())),
            uint256(_messageVersion)
        );
    }

    function testInitialization__setsTheMessageBodyVersion(
        uint32 _messageBodyVersion
    ) public {
        CCTPHookWrapper _wrapper = new CCTPHookWrapper(
            localMessageTransmitter,
            messageVersion,
            _messageBodyVersion
        );
        assertEq(
            uint256(address(_wrapper.supportedMessageBodyVersion())),
            uint256(_messageBodyVersion)
        );
    }

    function testRelay__revertsIfMessageFormatVersionIsInvalid(
        uint32 _messageVersion
    ) public {
        vm.assume(_messageVersion != messageVersion);

        vm.expectRevert("Invalid message version");
        bytes memory _message = _createMessage(
            _messageVersion,
            messageBodyVersion,
            bytes("")
        );
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageBodyVersionIsInvalid(
        uint32 _messageBodyVersion
    ) public {
        vm.assume(_messageBodyVersion != messageBodyVersion);

        vm.expectRevert("Invalid message body version");
        bytes memory _message = _createMessage(
            messageVersion,
            _messageBodyVersion,
            bytes("")
        );
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageTransmitterCallReverts() public {
        bytes memory _message = _createMessage(
            messageVersion,
            messageBodyVersion,
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
            "Testing: token minter failed"
        );

        vm.expectRevert();
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__revertsIfMessageTransmitterReturnsFalse() public {
        bytes memory _message = _createMessage(
            messageVersion,
            messageBodyVersion,
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
        wrapper.relay(_message, bytes(""));
    }

    function testRelay__succeedsWithNoHook() public {
        bytes memory _message = _createMessage(
            messageVersion,
            messageBodyVersion,
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
            messageVersion,
            messageBodyVersion,
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
        (
            bool _relaySuccess,
            bool _hookSuccess,
            bytes memory _returnData
        ) = wrapper.relay(_message, bytes(""));

        assertTrue(_relaySuccess);
        assertFalse(_hookSuccess);
        assertEq(_getRevertMsg(_returnData), "Hook failure");
    }

    function testRelay__succeedsWithCallToEOAHookTarget(
        bytes calldata _hookCalldata
    ) public {
        bytes memory _message = _createMessage(
            messageVersion,
            messageBodyVersion,
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
        // Prepare a message with hookCalldata that will fail
        uint256 _expectedReturnData = 12;
        bytes memory _succeedingHookCallData = abi.encodeWithSelector(
            MockHookTarget.succeedingHook.selector,
            5,
            7
        );
        bytes memory _message = _createMessage(
            messageVersion,
            messageBodyVersion,
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
                _messageVersion,
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
                _burnMessageVersion,
                bytes32(0),
                bytes32(0),
                uint256(0),
                bytes32(0),
                uint256(0),
                uint256(0),
                uint256(0),
                _hookData
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
