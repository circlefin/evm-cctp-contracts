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

import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {TestUtils} from "../TestUtils.sol";
import {MessageV2} from "../../src/messages/v2/MessageV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {IMessageHandlerV2} from "../../src/interfaces/v2/IMessageHandlerV2.sol";
import {MockReentrantCallerV2} from "../mocks/v2/MockReentrantCallerV2.sol";

contract MessageTransmitterV2Test is TestUtils {
    event MessageSent(bytes message);

    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        bytes32 indexed nonce,
        bytes32 sender,
        uint32 indexed finalityThresholdExecuted,
        bytes messageBody
    );

    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using MessageV2 for bytes29;

    // Test constants
    uint256 constant SIGNATURE_LENGTH = 65;

    uint32 localDomain = 1;
    uint32 remoteDomain = 2;

    MessageTransmitterV2 messageTransmitter;

    function setUp() public {
        // message transmitter on source domain
        messageTransmitter = new MessageTransmitterV2(
            localDomain,
            attester,
            maxMessageBodySize,
            version
        );
    }

    function testSendMessage_revertsWhenPaused(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody,
        address _pauser
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_pauser != address(0));
        vm.assume(_destinationDomain != localDomain);

        messageTransmitter.updatePauser(_pauser);

        vm.prank(_pauser);
        messageTransmitter.pause();
        assertTrue(messageTransmitter.paused());

        vm.expectRevert("Pausable: paused");
        messageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_revertsWhenSendingToLocalDomain(
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);

        vm.expectRevert("Domain is local domain");
        messageTransmitter.sendMessage(
            localDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_rejectsTooLargeMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_destinationDomain != localDomain);

        bytes memory _messageBody = new bytes(maxMessageBodySize + 1);

        vm.expectRevert("Message body exceeds max size");
        messageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_rejectsZeroRecipient(
        uint32 _destinationDomain,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public {
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_destinationDomain != localDomain);

        vm.expectRevert("Recipient must be nonzero");
        messageTransmitter.sendMessage(
            _destinationDomain,
            bytes32(0), // recipient
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_succeeds(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody,
        address _sender
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_destinationDomain != localDomain);

        _sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody,
            _sender
        );
    }

    function testReceiveMessage_revertsWhenPaused(
        bytes calldata _message,
        bytes calldata _attestation,
        address _pauser
    ) public {
        vm.assume(_pauser != address(0));

        // Pause
        messageTransmitter.updatePauser(_pauser);
        vm.prank(_pauser);
        messageTransmitter.pause();
        vm.stopPrank();

        // Sanity check
        assertTrue(messageTransmitter.paused());

        vm.expectRevert("Pausable: paused");
        messageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_revertsWithZeroLengthAttestation(
        bytes calldata _message
    ) public {
        vm.expectRevert("Invalid attestation length");
        messageTransmitter.receiveMessage(_message, "");
    }

    function testReceiveMessage_revertsWithTooShortAttestation(
        bytes calldata _message,
        bytes calldata _attestation
    ) public {
        _setup2of3Multisig();

        uint256 _expectedAttestationLength = 2 * SIGNATURE_LENGTH;
        vm.assume(
            _attestation.length > 0 &&
                _attestation.length < _expectedAttestationLength
        );

        vm.expectRevert("Invalid attestation length");
        messageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_revertsWithTooLongAttestation(
        bytes calldata _message
    ) public {
        _setup2of3Multisig();

        uint256 _expectedAttestationLength = 2 * SIGNATURE_LENGTH;
        bytes memory _attestation = new bytes(_expectedAttestationLength + 1);

        vm.expectRevert("Invalid attestation length");
        messageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_revertsWhenSignerIsNotEnabled(
        bytes calldata _message
    ) public {
        uint256[] memory _fakeAttesterPrivateKeys = new uint256[](1);
        _fakeAttesterPrivateKeys[0] = fakeAttesterPK;
        bytes memory _signature = _signMessage(
            _message,
            _fakeAttesterPrivateKeys
        );

        vm.expectRevert("Invalid signature: not attester");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfAttestationSignaturesAreOutOfOrder(
        bytes calldata _message
    ) public {
        _setup2of2Multisig();

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // manually sign, with attesters in reverse order
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = secondAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid signature order or dupe");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfFirstSignatureIsEmpty(
        bytes calldata _message
    ) public {
        _setup2of3Multisig();

        uint256[] memory _attesterPrivateKeys = new uint256[](1);
        _attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, _attesterPrivateKeys);

        bytes memory _validSignaturePrependedWithEmptySig = abi.encodePacked(
            zeroSignature,
            _signature
        );

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        messageTransmitter.receiveMessage(
            _message,
            _validSignaturePrependedWithEmptySig
        );
    }

    function testReceiveMessage_revertsIfLastSignatureIsEmpty(
        bytes calldata _message
    ) public {
        _setup2of3Multisig();

        uint256[] memory _attesterPrivateKeys = new uint256[](1);
        _attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, _attesterPrivateKeys);

        bytes memory _validSignaturePrependedWithEmptySig = abi.encodePacked(
            _signature,
            zeroSignature
        );

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        messageTransmitter.receiveMessage(
            _message,
            _validSignaturePrependedWithEmptySig
        );
    }

    function testReceiveMessage_revertsIfAttestationHasDuplicatedSignatures(
        bytes calldata _message
    ) public {
        _setup2of3Multisig();

        uint256[] memory _attesterPrivateKeys = new uint256[](2);
        // attempt to use same private key to sign twice (disallowed)
        _attesterPrivateKeys[0] = attesterPK;
        _attesterPrivateKeys[1] = attesterPK;
        bytes memory _signature = _signMessage(_message, _attesterPrivateKeys);

        vm.expectRevert("Invalid signature order or dupe");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfAttestationSignaturesAreAllEmpty(
        bytes calldata _message
    ) public {
        _setup2of3Multisig();
        bytes memory _emptySigs = abi.encodePacked(
            zeroSignature,
            zeroSignature
        );

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        messageTransmitter.receiveMessage(_message, _emptySigs);
    }

    function testReceiveMessage_revertsIfMessageIsTooShort(
        bytes calldata _message
    ) public {
        // See: MessageV2.sol#MESSAGE_BODY_INDEX
        vm.assume(_message.length < 148);

        // Produce a valid signature
        bytes memory _signature = _sign1of1Message(_message);

        vm.expectRevert("Invalid message: too short");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfMessageHasInvalidDestinationDomain(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_destinationDomain != messageTransmitter.localDomain());
        bytes memory _message = _formatMessageForReceive(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );

        bytes memory _attestation = _sign1of1Message(_message);

        vm.expectRevert("Invalid destination domain");
        messageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_revertsIfCallerIsNotNonZeroDestinationCaller(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody,
        address _caller
    ) public {
        vm.assume(_caller != destinationCallerAddr);

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            _recipient,
            destinationCaller,
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);

        vm.prank(_caller);
        vm.expectRevert("Invalid caller for message");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfMessageVersionIsInvalid(
        uint32 _version,
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_version != version);

        bytes memory _message = _formatMessageForReceive(
            _version,
            _sourceDomain,
            destinationDomain,
            _nonce,
            _sender,
            _recipient,
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );

        bytes memory _attestation = _sign1of1Message(_message);

        if (_destinationCaller != address(0)) {
            vm.prank(_destinationCaller);
        }
        vm.expectRevert("Invalid message version");
        messageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_revertsIfHandleReceiveFinalizedMessageReverts(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted >=
                messageTransmitter.finalizedMessageThreshold()
        );

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);

        // Mock a revert
        bytes memory _call = abi.encodeWithSelector(
            IMessageHandlerV2.handleReceiveFinalizedMessage.selector,
            _sourceDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
        vm.mockCallRevert(_recipient, _call, "Testing");

        vm.prank(_destinationCaller);
        vm.expectRevert();
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfHandleReceiveUnfinalizedMessageReverts(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted <
                messageTransmitter.finalizedMessageThreshold()
        );

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);

        // Mock a revert
        bytes memory _call = abi.encodeWithSelector(
            IMessageHandlerV2.handleReceiveUnfinalizedMessage.selector,
            _sourceDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
        vm.mockCallRevert(_recipient, _call, "Testing");

        vm.prank(_destinationCaller);
        vm.expectRevert();
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfHandleReceiveFinalizedMessageReturnsFalse(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted >=
                messageTransmitter.finalizedMessageThreshold()
        );
        vm.assume(_recipient != foundryCheatCodeAddr);

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);

        // Mock returning false
        bytes memory _call = abi.encodeWithSelector(
            IMessageHandlerV2.handleReceiveFinalizedMessage.selector,
            _sourceDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
        vm.mockCall(_recipient, _call, abi.encode(false));
        vm.expectCall(_recipient, _call);

        vm.prank(_destinationCaller);
        vm.expectRevert("handleReceiveFinalizedMessage() failed");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfHandleReceiveUnfinalizedMessageReturnsFalse(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted <
                messageTransmitter.finalizedMessageThreshold()
        );
        vm.assume(_recipient != foundryCheatCodeAddr);

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);

        // Mock returning false
        bytes memory _call = abi.encodeWithSelector(
            IMessageHandlerV2.handleReceiveUnfinalizedMessage.selector,
            _sourceDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
        vm.mockCall(_recipient, _call, abi.encode(false));
        vm.expectCall(_recipient, _call, 1);

        vm.prank(_destinationCaller);
        vm.expectRevert("handleReceiveUnfinalizedMessage() failed");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsIfNonceIsAlreadyUsed(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);

        // Try again
        vm.prank(_destinationCaller);
        vm.expectRevert("Nonce already used");
        messageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsReusedNonceFromReentrantCaller(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted
    ) public {
        MockReentrantCallerV2 _mockReentrantCaller = new MockReentrantCallerV2();

        // Encode mockReentrantCaller as recipient
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(address(_mockReentrantCaller)),
            bytes32(0),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            bytes("reenter")
        );
        bytes memory _signature = _sign1of1Message(_message);
        _mockReentrantCaller.setMessageAndSignature(_message, _signature);

        // fail to call receiveMessage twice in same transaction
        vm.expectRevert("Re-entrant call failed due to reused nonce");
        messageTransmitter.receiveMessage(_message, _signature);

        // Check that nonce was not consumed
        assertEq(messageTransmitter.usedNonces(_nonce), 0);
    }

    function testReceiveMessage_succeedsWith1of1Signing(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWith2of2Signing(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        _setup2of2Multisig();

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign2OfNMultisigMessage(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWith2of3Signing(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        _setup2of3Multisig();

        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign2OfNMultisigMessage(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWithFinalizedMessage(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted >=
                messageTransmitter.finalizedMessageThreshold()
        );
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWithUnfinalizedMessage(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted <
                messageTransmitter.finalizedMessageThreshold()
        );
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWithNonZeroDestinationCaller(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        address _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_destinationCaller != address(0));
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            AddressUtils.addressToBytes32(_destinationCaller),
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWithZeroDestinationCaller(
        uint32 _sourceDomain,
        bytes32 _nonce,
        bytes32 _sender,
        address _recipient,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        bytes memory _message = _formatMessageForReceive(
            version,
            _sourceDomain,
            localDomain,
            _nonce,
            _sender,
            AddressUtils.addressToBytes32(_recipient),
            bytes32(0), // destinationCaller
            _minFinalityThreshold,
            _finalityThresholdExecuted,
            _messageBody
        );
        bytes memory _signature = _sign1of1Message(_message);
        _receiveMessage(_message, _signature);
    }

    function testSendMaxMessageBodySize_revertsOnNonOwner(
        uint256 _newMaxMessageBodySize,
        address _notOwner
    ) public {
        vm.assume(_notOwner != messageTransmitter.owner());
        expectRevertWithWrongOwner(_notOwner);
        messageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
    }

    function testSetMaxMessageBodySize_succeeds(
        uint256 _newMaxMessageBodySize
    ) public {
        vm.assume(_newMaxMessageBodySize != maxMessageBodySize);

        // Set new max size
        vm.expectEmit(true, true, true, true);
        emit MaxMessageBodySizeUpdated(_newMaxMessageBodySize);
        messageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
        assertEq(
            messageTransmitter.maxMessageBodySize(),
            _newMaxMessageBodySize
        );
    }

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount,
        address _nonRescuer
    ) public {
        assertContractIsRescuable(
            address(messageTransmitter),
            _rescuer,
            _rescueRecipient,
            _amount,
            _nonRescuer
        );
    }

    function testPausable(
        address _currentPauser,
        address _newPauser,
        address _nonOwner
    ) public {
        vm.assume(_currentPauser != address(0));
        messageTransmitter.updatePauser(_currentPauser);

        assertContractIsPausable(
            address(messageTransmitter),
            _currentPauser,
            _newPauser,
            messageTransmitter.owner(),
            _nonOwner
        );
    }

    function testTransferOwnership_revertsFromNonOwner(
        address _newOwner,
        address _nonOwner
    ) public {
        transferOwnership_revertsFromNonOwner(
            address(messageTransmitter),
            _newOwner,
            _nonOwner
        );
    }

    function testAcceptOwnership_revertsFromNonPendingOwner(
        address _newOwner,
        address _nonOwner
    ) public {
        acceptOwnership_revertsFromNonPendingOwner(
            address(messageTransmitter),
            _newOwner,
            _nonOwner
        );
    }

    function testTransferOwnershipAndAcceptOwnership(address _newOwner) public {
        transferOwnershipAndAcceptOwnership(
            address(messageTransmitter),
            _newOwner
        );
    }

    function testTransferOwnershipWithoutAcceptingThenTransferToNewOwner(
        address _newOwner,
        address _secondNewOwner
    ) public {
        transferOwnershipWithoutAcceptingThenTransferToNewOwner(
            address(messageTransmitter),
            _newOwner,
            _secondNewOwner
        );
    }

    // Internal utility functions

    function _sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes memory _messageBody,
        address _sender
    ) internal {
        bytes memory _expectedMessage = MessageV2._formatMessageForRelay(
            version,
            localDomain,
            _destinationDomain,
            AddressUtils.addressToBytes32(_sender),
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );

        assertFalse(messageTransmitter.paused());

        // assert that a MessageSent event was logged with expected message bytes
        vm.prank(_sender);
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);
        messageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
        vm.stopPrank();
    }

    function _receiveMessage(
        bytes memory _message,
        bytes memory _signature
    ) internal {
        bytes29 _msg = _message.ref(0);
        address _recipient = AddressUtils.bytes32ToAddress(
            _msg._getRecipient()
        );
        vm.assume(_recipient != foundryCheatCodeAddr);

        // Mock a successful response from IMessageHandlerV2 to message.recipient,
        // and expect it to be called once.
        bytes memory _encodedMessageHandlerCall = abi.encodeWithSelector(
            _msg._getFinalityThresholdExecuted() >=
                messageTransmitter.finalizedMessageThreshold()
                ? IMessageHandlerV2.handleReceiveFinalizedMessage.selector
                : IMessageHandlerV2.handleReceiveUnfinalizedMessage.selector,
            _msg._getSourceDomain(),
            _msg._getSender(),
            _msg._getFinalityThresholdExecuted(),
            _msg._getMessageBody().clone()
        );
        vm.mockCall(_recipient, _encodedMessageHandlerCall, abi.encode(true));
        vm.expectCall(_recipient, _encodedMessageHandlerCall, 1);

        // Spoof the destination caller
        address _caller = AddressUtils.bytes32ToAddress(
            _msg._getDestinationCaller()
        );

        // assert that a MessageReceive event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(
            _caller,
            _msg._getSourceDomain(),
            _msg._getNonce(),
            _msg._getSender(),
            _msg._getFinalityThresholdExecuted(),
            _msg._getMessageBody().clone()
        );

        // Receive message
        vm.prank(_caller);
        assertTrue(messageTransmitter.receiveMessage(_message, _signature));
        vm.stopPrank();

        // Check that the nonce is now used
        assertEq(messageTransmitter.usedNonces(_msg._getNonce()), 1);
    }

    // setup second and third attester (first set in setUp()); set sig threshold at 2
    function _setup2of3Multisig() internal {
        messageTransmitter.enableAttester(secondAttester);
        messageTransmitter.enableAttester(thirdAttester);
        messageTransmitter.setSignatureThreshold(2);
    }

    // setup second attester (first set in setUp()); set sig threshold at 2
    function _setup2of2Multisig() internal {
        messageTransmitter.enableAttester(secondAttester);
        messageTransmitter.setSignatureThreshold(2);
    }

    function _sign1of1Message(
        bytes memory _message
    ) internal returns (bytes memory) {
        uint256[] memory _privateKeys = new uint256[](1);
        _privateKeys[0] = attesterPK;
        return _signMessage(_message, _privateKeys);
    }

    function _sign2OfNMultisigMessage(
        bytes memory _message
    ) internal returns (bytes memory _signature) {
        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // manually sort attesters in correct order
        attesterPrivateKeys[1] = attesterPK;
        // attester == 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf
        attesterPrivateKeys[0] = secondAttesterPK;
        // second attester = 0x6813eb9362372eef6200f3b1dbc3f819671cba69
        // sanity check order
        assertTrue(attester > secondAttester);
        assertTrue(secondAttester > address(0));
        return _signMessage(_message, attesterPrivateKeys);
    }

    function _formatMessageForReceive(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        uint32 _finalityThresholdExecuted,
        bytes memory _messageBody
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _version,
                _sourceDomain,
                _destinationDomain,
                _nonce,
                _sender,
                _recipient,
                _destinationCaller,
                _minFinalityThreshold,
                _finalityThresholdExecuted,
                _messageBody
            );
    }
}
