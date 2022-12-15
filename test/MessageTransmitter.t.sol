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

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./mocks/MockTokenMessenger.sol";
import "./mocks/MockReentrantCaller.sol";
import "../src/interfaces/IReceiver.sol";
import "../src/MessageTransmitter.sol";
import "../lib/forge-std/src/Test.sol";
import "./TestUtils.sol";

contract MessageTransmitterTest is Test, TestUtils {
    MessageTransmitter srcMessageTransmitter;
    MessageTransmitter destMessageTransmitter;
    MockTokenMessenger srcMockTokenMessenger;
    MockTokenMessenger destMockTokenMessenger;
    MockReentrantCaller mockReentrantCaller;

    address pauser = vm.addr(1509);
    bytes newMessageBody = "new message body";

    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when a new message is received
     * @param caller Caller (msg.sender) on destination domain
     * @param sourceDomain The source domain this message originated from
     * @param nonce The nonce unique to this message
     * @param sender The sender of this message
     * @param messageBody message body bytes
     */
    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        uint64 indexed nonce,
        bytes32 sender,
        bytes messageBody
    );

    /**
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;

    function setUp() public {
        // message transmitter on source domain
        srcMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );

        // message transmitter on destination domain
        destMessageTransmitter = new MessageTransmitter(
            destinationDomain,
            attester,
            maxMessageBodySize,
            version
        );

        srcMockTokenMessenger = new MockTokenMessenger();
        destMockTokenMessenger = new MockTokenMessenger();

        recipient = bytes32(uint256(uint160(address(destMockTokenMessenger))));
        sender = bytes32(uint256(uint160(address(srcMockTokenMessenger))));
        srcMessageTransmitter.updatePauser(pauser);
    }

    function testSendMessage_rejectsTooLargeMessage() public {
        bytes32 _recipient = bytes32(uint256(uint160(vm.addr(1505))));
        bytes memory _messageBody = new bytes(8 * 2**10 + 1);
        vm.expectRevert("Message body exceeds max size");
        srcMessageTransmitter.sendMessage(
            destinationDomain,
            _recipient,
            _messageBody
        );
    }

    function testSendMessage_rejectsZeroRecipient(
        uint32 _destinationDomain,
        bytes memory _messageBody
    ) public {
        vm.expectRevert("Recipient must be nonzero");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            bytes32(0),
            _messageBody
        );
    }

    function testSendMessage_revertsWhenPaused(
        uint32 _destinationDomain,
        bytes memory _messageBody
    ) public {
        vm.prank(pauser);
        srcMessageTransmitter.pause();
        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            recipient,
            _messageBody
        );

        // sendMessage works again after unpause
        vm.prank(pauser);
        srcMessageTransmitter.unpause();
        _sendMessage(
            version,
            sourceDomain,
            _destinationDomain,
            sender,
            recipient,
            messageBody
        );
    }

    function testSendMessage_fuzz(uint32 _destinationDomain) public {
        _sendMessage(
            version,
            sourceDomain,
            _destinationDomain,
            sender,
            recipient,
            messageBody
        );
    }

    function testSendAndReceiveMessage(address _caller) public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        _receiveMessage(
            _caller,
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );
    }

    function testReceiveMessage_fuzz(
        address _caller,
        uint32 _sourceDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes memory _messageBody
    ) public {
        _receiveMessage(
            _caller,
            version,
            _sourceDomain,
            destinationDomain, // static (messageRecipient must be deployed on the destination domain)
            _nonce,
            _sender,
            recipient, // static (recipient must be a valid IMessageRecipient)
            emptyDestinationCaller,
            _messageBody
        );
    }

    function testReceiveMessage_rejectInvalidDestinationDomain() public {
        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            2,
            nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid destination domain");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectInvalidVersion() public {
        bytes memory _message = Message._formatMessage(
            2,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid message version");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectInvalidMessage() public {
        bytes memory _message = "foo";

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid message: too short");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsNotEnabledSigner() public {
        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );

        uint256[] memory fakeAttesterPrivateKeys = new uint256[](1);
        fakeAttesterPrivateKeys[0] = fakeAttesterPK;
        bytes memory _signature = _signMessage(
            _message,
            fakeAttesterPrivateKeys
        );

        vm.expectRevert("Invalid signature: not attester");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsMessageIfNonzeroDestinationCallerDoesNotMatchSender(
        uint32 _sourceDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes memory _messageBody
    ) public {
        bytes memory _message = Message._formatMessage(
            version,
            _sourceDomain,
            destinationDomain,
            _nonce,
            _sender,
            _recipient,
            destinationCaller,
            _messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid caller for message");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsWithNonzeroDestinationCaller() public {
        uint64 _msgNonce = _sendMessageWithCaller(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            destinationCaller,
            messageBody
        );

        _receiveMessage(
            destinationCallerAddr,
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            destinationCaller,
            messageBody
        );
    }

    function testReplaceMessage_revertsWhenPaused(
        bytes memory _originalMessage,
        bytes calldata _originalAttestation,
        bytes memory _newMessageBody,
        bytes32 _newDestinationCaller
    ) public {
        vm.prank(pauser);
        srcMessageTransmitter.pause();
        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.replaceMessage(
            _originalMessage,
            _originalAttestation,
            _newMessageBody,
            _newDestinationCaller
        );
    }

    function testReplaceMessage_revertsOnInvalidSignature() public {
        _setup2of3Multisig();

        bytes memory _originalMessage = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // attempt to use same private key to sign twice (disallowed)
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = attesterPK;
        bytes memory _originalAttestation = _signMessage(
            _originalMessage,
            attesterPrivateKeys
        );

        vm.expectRevert("Invalid signature order or dupe");

        destMessageTransmitter.replaceMessage(
            _originalMessage,
            _originalAttestation,
            messageBody,
            emptyDestinationCaller
        );
    }

    function testReplaceMessage_revertsOnInvalidMessage() public {
        bytes memory _originalMessage = "foo";

        _setup2of3Multisig();

        // sign replaced message
        bytes memory _replacingMessageSignature = _sign2OfNMultisigMessage(
            _originalMessage
        );

        vm.expectRevert("Invalid message: too short");
        destMessageTransmitter.replaceMessage(
            _originalMessage,
            _replacingMessageSignature,
            messageBody,
            emptyDestinationCaller
        );
    }

    function testReplaceMessage_revertsOnWrongSender() public {
        _setup2of3Multisig();

        bytes memory _originalMessage = _getMessage();
        assertEq(_originalMessage.ref(0)._sender(), sender);

        bytes memory _signature = _sign2OfNMultisigMessage(_originalMessage);

        address _newMintRecipientAddr = vm.addr(1802);
        address _newDestinationCallerAddr = vm.addr(1803);

        bytes32 _newDestinationCaller = Message.addressToBytes32(
            _newDestinationCallerAddr
        );

        vm.prank(_newMintRecipientAddr);
        vm.expectRevert("Sender not permitted to use nonce");
        srcMessageTransmitter.replaceMessage(
            _originalMessage,
            _signature,
            messageBody,
            _newDestinationCaller
        );
    }

    function testReplaceMessage_revertsOnWrongSourceDomain() public {
        _setup2of3Multisig();

        bytes memory _originalMessage = _getMessage();
        assertEq(_originalMessage.ref(0)._sender(), sender);

        bytes memory _signature = _sign2OfNMultisigMessage(_originalMessage);
        address _newDestinationCallerAddr = vm.addr(1803);

        bytes32 _newDestinationCaller = Message.addressToBytes32(
            _newDestinationCallerAddr
        );

        bytes memory _newMessageBody = "newMessageBody";

        // assert that a MessageSent event was logged with expected message bytes
        vm.prank(Message.bytes32ToAddress(sender));
        vm.expectRevert("Message not originally sent from this domain");
        destMessageTransmitter.replaceMessage(
            _originalMessage,
            _signature,
            _newMessageBody,
            _newDestinationCaller
        );
    }

    function testReplaceMessage_succeeds(address _newDestinationCallerAddr)
        public
    {
        bytes memory _originalMessage = _getMessage();
        bytes memory _expectedMessage = _replaceMessage(
            _originalMessage,
            _newDestinationCallerAddr
        );

        bytes29 _m = _originalMessage.ref(0);

        // sign replaced message
        bytes memory _replacingMessageSignature = _sign2OfNMultisigMessage(
            _expectedMessage
        );

        // test receiving the replaced message
        vm.prank(_newDestinationCallerAddr);
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(
            _newDestinationCallerAddr,
            sourceDomain,
            _m._nonce(),
            sender,
            newMessageBody
        );

        destMessageTransmitter.receiveMessage(
            _expectedMessage,
            _replacingMessageSignature
        );
    }

    function testReplaceMessage_succeedsButFailsToReserveNonceInReceiveMessage(
        address _newDestinationCallerAddr
    ) public {
        _setup2of3Multisig();

        bytes memory _originalMessage = _getMessage();
        bytes memory _signature = _sign2OfNMultisigMessage(_originalMessage);

        bytes32 _newDestinationCaller = Message.addressToBytes32(
            _newDestinationCallerAddr
        );

        bytes29 _m = _originalMessage.ref(0);
        bytes memory _expectedMessage = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _m._nonce(),
            sender,
            recipient,
            _newDestinationCaller,
            newMessageBody
        );

        // assert that a MessageSent event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);

        vm.prank(Message.bytes32ToAddress(sender));
        srcMessageTransmitter.replaceMessage(
            _originalMessage,
            _signature,
            newMessageBody,
            _newDestinationCaller
        );

        // sign original message
        bytes memory _originalSignature = _sign2OfNMultisigMessage(
            _originalMessage
        );

        // receive original message
        // test receiving the replaced message
        vm.expectEmit(true, true, true, true);
        address owner = vm.addr(1801);
        emit MessageReceived(
            owner,
            _m._sourceDomain(),
            _m._nonce(),
            sender,
            _m._messageBody().clone()
        );

        vm.prank(owner);
        destMessageTransmitter.receiveMessage(
            _originalMessage,
            _originalSignature
        );

        // sign replaced message
        bytes memory _replacingMessageSignature = _sign2OfNMultisigMessage(
            _expectedMessage
        );

        // fail to receive the replace (original message at nonce already received)
        vm.prank(_newDestinationCallerAddr);
        vm.expectRevert("Nonce already used");
        destMessageTransmitter.receiveMessage(
            _expectedMessage,
            _replacingMessageSignature
        );
    }

    function testSendMessageWithCaller_rejectsZeroCaller(
        uint64 _nonce,
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes memory _messageBody
    ) public {
        Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            emptyDestinationCaller,
            _messageBody
        );

        vm.expectRevert("Destination caller must be nonzero");
        srcMessageTransmitter.sendMessageWithCaller(
            _destinationDomain,
            _recipient,
            emptyDestinationCaller,
            _messageBody
        );
    }

    function testReceiveMessage_succeedsFor2of3Multisig() public {
        _setup2of3Multisig();
        _sendReceiveMultisigMessage(destinationCallerAddr);
    }

    function testReceiveMessage_succeedsfor2of2Multisig() public {
        _setup2of2Multisig();
        _sendReceiveMultisigMessage(destinationCallerAddr);
    }

    function testReceiveMessage_rejectsAttestationWithOutOfOrderSigners()
        public
    {
        _setup2of2Multisig();
        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // // manually sort attesters in incorrect order
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = secondAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid signature order or dupe");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsSignatureOfLengthZero() public {
        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](0);
        // manually sort attesters in incorrect order
        bytes memory _signature = "";

        // reverts because signature length 65 (immutable value) * signatureThreshold 1 (cannot be set to 0) != 0
        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsMessageOfLengthZero() public {
        bytes memory _message = "";

        bytes memory _signature = _sign2OfNMultisigMessage(_message);

        // reverts because signature length 65 (immutable value) * signatureThreshold 1 (cannot be set to 0) != 0
        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsAttestationWithDuplicateSigners()
        public
    {
        _setup2of3Multisig();

        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // attempt to use same private key to sign twice (disallowed)
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid signature order or dupe");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsAttestionWithTooFewSignatures() public {
        _setup2of3Multisig();

        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        // use only 1 key (2 required)
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsAttestationWithTooManySignatures()
        public
    {
        _setup2of3Multisig();

        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](3);
        // use only 3 key (only 2 allowed)
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = secondAttesterPK;
        attesterPrivateKeys[2] = thirdAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsAttestationWithSingleEmptySigPrefix()
        public
    {
        _setup2of3Multisig();

        bytes memory _message = _getMessage();

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        bytes memory _validSignaturePrependedWithEmptySig = abi.encodePacked(
            zeroSignature,
            zeroSignature
        );

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        destMessageTransmitter.receiveMessage(
            _message,
            _validSignaturePrependedWithEmptySig
        );
    }

    function testReceiveMessage_rejectsAttestationWithAllEmptySigs() public {
        _setup2of3Multisig();

        bytes memory _message = _getMessage();

        bytes memory _validSignaturePrependedWithEmptySig = abi.encodePacked(
            zeroSignature,
            zeroSignature
        );

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        destMessageTransmitter.receiveMessage(
            _message,
            _validSignaturePrependedWithEmptySig
        );
    }

    function testReceiveMessage_rejectsAttestionWithRandomNumberOfBytesOfInvalidLength(
        uint8 _numberOfBytes
    ) public {
        bytes memory _attestation = "";
        bytes memory _message = _getMessage();
        // ensure less than 65 bytes so the length is never valid during fuzz testing
        for (uint256 i = 0; i < Math.min(_numberOfBytes, 64); i++) {
            _attestation = abi.encodePacked(
                _attestation,
                "1" // arbitrary value
            );
        }

        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _attestation);
    }

    function testReceiveMessage_rejectsReusedNonceInSeparateMessage(
        address _caller
    ) public {
        // successfully receiveMessage
        (bytes memory _message, bytes memory _signature) = _receiveMessage(
            _caller,
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );

        // fail to call receiveMessage again with same nonce
        vm.expectRevert("Nonce already used");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsReusedNonceFromReentrantCaller() public {
        MockReentrantCaller _mockReentrantCaller = new MockReentrantCaller();

        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            Message.addressToBytes32(address(_mockReentrantCaller)),
            emptyDestinationCaller,
            bytes("reenter")
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        _mockReentrantCaller.setMessageAndSignature(_message, _signature);

        // fail to call receiveMessage twice in same transaction
        vm.expectRevert("Re-entrant call failed due to reused nonce");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_doesNotUseNonceOnRevert(uint32 _nonce) public {
        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            "revert"
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("mock revert");
        destMessageTransmitter.receiveMessage(_message, _signature);

        // check that the nonce is not used
        assertEq(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(sourceDomain, _nonce)
            ),
            0
        );
    }

    function testReceiveMessage_revertsIfHandleReceiveMessageReturnsFalse()
        public
    {
        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            bytes("return false")
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("handleReceiveMessage() failed");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_revertsWhenPaused(
        bytes memory _message,
        bytes memory _signature,
        address _caller
    ) public {
        vm.prank(pauser);
        srcMessageTransmitter.pause();
        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.receiveMessage(_message, _signature);

        // receiveMessage works again after unpause
        vm.prank(pauser);
        srcMessageTransmitter.unpause();
        uint64 _nonce = srcMessageTransmitter.nextAvailableNonce();
        _receiveMessage(
            _caller,
            version,
            sourceDomain,
            destinationDomain,
            _nonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );
    }

    function testSetMaxMessageBodySize() public {
        uint32 _newMaxMessageBodySize = 10000000;

        MessageTransmitter _messageTransmitter = new MessageTransmitter(
            destinationDomain,
            attester,
            maxMessageBodySize,
            version
        );

        // Try sending too large message
        bytes memory _messageBody = new bytes(_newMaxMessageBodySize);
        vm.expectRevert("Message body exceeds max size");
        _messageTransmitter.sendMessage(
            destinationDomain,
            recipient,
            _messageBody
        );

        // Set new max size
        vm.expectEmit(true, true, true, true);
        emit MaxMessageBodySizeUpdated(_newMaxMessageBodySize);
        _messageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);

        // Send message body with new max size, successfully
        _messageTransmitter.sendMessage(
            destinationDomain,
            recipient,
            _messageBody
        );
    }

    function testSendMaxMessageBodySize_revertsOnNonOwner(
        uint256 _newMaxMessageBodySize
    ) public {
        expectRevertWithWrongOwner();
        srcMessageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
    }

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount
    ) public {
        assertContractIsRescuable(
            address(srcMessageTransmitter),
            _rescuer,
            _rescueRecipient,
            _amount
        );
    }

    function testPausable(address _newPauser) public {
        assertContractIsPausable(
            address(srcMessageTransmitter),
            pauser,
            _newPauser,
            srcMessageTransmitter.owner()
        );
    }

    function testTransferOwnershipAndAcceptOwnership() public {
        address _newOwner = vm.addr(1509);
        transferOwnershipAndAcceptOwnership(
            address(srcMessageTransmitter),
            _newOwner
        );
    }

    function testTransferOwnershipWithoutAcceptingThenTransferToNewOwner(
        address _newOwner,
        address _secondNewOwner
    ) public {
        transferOwnershipWithoutAcceptingThenTransferToNewOwner(
            address(srcMessageTransmitter),
            _newOwner,
            _secondNewOwner
        );
    }

    /**
     * @notice hashes `_source` and `_nonce`.
     * @param _source Domain of chain where the transfer originated
     * @param _nonce The unique identifier for the message from source to
              destination
     * @return Returns hash of source and nonce
     */
    function _hashSourceAndNonce(uint32 _source, uint64 _nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_source, _nonce));
    }

    function _sendMessage(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes memory _messageBody
    ) internal returns (uint64 msgNonce) {
        uint64 _nonce = srcMessageTransmitter.nextAvailableNonce();

        bytes memory _expectedMessage = Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            emptyDestinationCaller,
            _messageBody
        );

        // assert that a MessageSent event was logged with expected message bytes
        vm.prank(Message.bytes32ToAddress(_sender));
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);

        uint64 _nonceReserved = srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _messageBody
        );

        assertEq(uint256(_nonceReserved), uint256(_nonce));

        // assert nextAvailableNonce was updated
        uint256 _incrementedNonce = srcMessageTransmitter.nextAvailableNonce();

        assertEq(_incrementedNonce, uint256(_nonce + 1));

        return _nonce;
    }

    function _sendMessageWithCaller(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        bytes memory _messageBody
    ) internal returns (uint64 msgNonce) {
        uint64 _nonce = srcMessageTransmitter.nextAvailableNonce();

        bytes memory _expectedMessage = Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        // assert that a MessageSent event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);

        vm.prank(Message.bytes32ToAddress(_sender));
        uint64 _nonceReserved = srcMessageTransmitter.sendMessageWithCaller(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        assertEq(uint256(_nonceReserved), uint256(_nonce));

        // assert nextAvailableNonce was updated
        uint256 _incrementedNonce = srcMessageTransmitter.nextAvailableNonce();

        assertEq(_incrementedNonce, uint256(_nonce + 1));

        return _nonce;
    }

    function _receiveMessage(
        address _caller,
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        bytes memory _messageBody
    ) internal returns (bytes memory, bytes memory) {
        bytes memory _message = Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        bytes memory _signature = _signMessageWithAttesterPK(_message);

        // assert that a MessageReceive event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(
            _caller,
            _sourceDomain,
            _nonce,
            _sender,
            _messageBody
        );

        vm.prank(_caller);
        bool success = destMessageTransmitter.receiveMessage(
            _message,
            _signature
        );
        assertTrue(success);

        // check that the nonce is used
        assertEq(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(_sourceDomain, _nonce)
            ),
            1
        );

        return (_message, _signature);
    }

    // ============ Internal: Utils ============
    function _getMessage() internal returns (bytes memory) {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        return
            Message._formatMessage(
                version,
                sourceDomain,
                destinationDomain,
                _msgNonce,
                sender,
                recipient,
                emptyDestinationCaller,
                messageBody
            );
    }

    function _sendReceiveMultisigMessage(address _caller) internal {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            emptyDestinationCaller,
            messageBody
        );

        bytes memory _signature = _sign2OfNMultisigMessage(_message);

        // assert that a MessageReceive event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(
            _caller,
            sourceDomain,
            _msgNonce,
            sender,
            messageBody
        );

        vm.prank(_caller);
        bool success = destMessageTransmitter.receiveMessage(
            _message,
            _signature
        );
        assertTrue(success);

        // check that the nonce is used
        assertEq(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(sourceDomain, _msgNonce)
            ),
            1
        );
    }

    // setup second and third attester (first set in constructor), set sig threshold at 2
    function _setup2of3Multisig() internal {
        destMessageTransmitter.enableAttester(secondAttester);
        destMessageTransmitter.enableAttester(thirdAttester);
        destMessageTransmitter.setSignatureThreshold(2);

        srcMessageTransmitter.enableAttester(secondAttester);
        srcMessageTransmitter.enableAttester(thirdAttester);
        srcMessageTransmitter.setSignatureThreshold(2);
    }

    // setup second and third attester (first set in constructor), set sig threshold at 2
    function _setup2of2Multisig() internal {
        destMessageTransmitter.enableAttester(secondAttester);
        destMessageTransmitter.setSignatureThreshold(2);
    }

    function _sign2OfNMultisigMessage(bytes memory _message)
        internal
        returns (bytes memory _signature)
    {
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

    function _replaceMessage(
        bytes memory _originalMessage,
        address _newDestinationCallerAddr
    ) internal returns (bytes memory replacedMsg) {
        _setup2of3Multisig();

        bytes memory _signature = _sign2OfNMultisigMessage(_originalMessage);

        bytes32 _newDestinationCaller = Message.addressToBytes32(
            _newDestinationCallerAddr
        );

        bytes29 _m = _originalMessage.ref(0);
        bytes memory _expectedMessage = Message._formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _m._nonce(),
            sender,
            recipient,
            _newDestinationCaller,
            newMessageBody
        );

        // assert that a MessageSent event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);
        vm.prank(Message.bytes32ToAddress(sender));
        srcMessageTransmitter.replaceMessage(
            _originalMessage,
            _signature,
            newMessageBody,
            _newDestinationCaller
        );
        return _expectedMessage;
    }
}
