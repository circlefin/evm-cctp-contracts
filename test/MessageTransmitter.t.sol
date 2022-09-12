/* SPDX-License-Identifier: UNLICENSED
 *
 * Copyright (c) 2022, Circle Internet Financial Trading Company Limited.
 * All rights reserved.
 *
 * Circle Internet Financial Trading Company Limited CONFIDENTIAL
 *
 * This file includes unpublished proprietary source code of Circle Internet
 * Financial Trading Company Limited, Inc. The copyright notice above does not
 * evidence any actual or intended publication of such source code. Disclosure
 * of this source code or any related proprietary information is strictly
 * prohibited without the express written permission of Circle Internet Financial
 * Trading Company Limited.
 */
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./mocks/MockCircleBridge.sol";
import "./mocks/MockReentrantCaller.sol";
import "./mocks/MockRepeatCaller.sol";
import "../src/interfaces/IReceiver.sol";
import "../src/MessageTransmitter.sol";
import "../lib/forge-std/src/Test.sol";
import "./TestUtils.sol";

contract MessageTransmitterTest is Test, TestUtils {
    MessageTransmitter srcMessageTransmitter;
    MessageTransmitter destMessageTransmitter;
    MockCircleBridge srcMockCircleBridge;
    MockCircleBridge destMockCircleBridge;
    MockReentrantCaller mockReentrantCaller;

    uint32 sourceDomain = 0;
    uint32 destinationDomain = 1;
    uint32 version = 0;
    uint32 nonce = 99;
    bytes32 sender;
    bytes32 recipient;
    bytes messageBody = bytes("test message");
    // 8 KiB
    uint32 maxMessageBodySize = 8 * 2**10;

    uint256 attesterPK = 1;
    uint256 fakeAttesterPK = 2;
    uint256 secondAttesterPK = 3;
    uint256 thirdAttesterPK = 4;
    address attester = vm.addr(attesterPK);
    address secondAttester = vm.addr(secondAttesterPK);
    address thirdAttester = vm.addr(thirdAttesterPK);
    address fakeAttester = vm.addr(fakeAttesterPK);
    address pauser = vm.addr(1509);

    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when a new message is received
     * @param sourceDomain The source domain this message originated from
     * @param nonce The nonce unique to this message
     * @param sender The sender of this message
     * @param messageBody message body bytes
     */
    event MessageReceived(
        uint32 sourceDomain,
        uint64 nonce,
        bytes32 sender,
        bytes messageBody
    );

    /**
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    /**
     * @notice Emitted when an attester is enabled
     * @param attester newly enabled attester
     */
    event AttesterEnabled(address attester);

    /**
     * @notice Emitted when an attester is disabled
     * @param attester newly disabled attester
     */
    event AttesterDisabled(address attester);

    /**
     * @notice Emitted when threshold number of attestations (m in m/n multisig) is updated
     * @param oldSignatureThreshold old signature threshold
     * @param newSignatureThreshold new signature threshold
     */
    event SignatureThresholdUpdated(
        uint256 oldSignatureThreshold,
        uint256 newSignatureThreshold
    );

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

        srcMockCircleBridge = new MockCircleBridge();
        destMockCircleBridge = new MockCircleBridge();

        recipient = bytes32(uint256(uint160(address(destMockCircleBridge))));
        sender = bytes32(uint256(uint160(address(srcMockCircleBridge))));
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

    function testSendMessage_revertsWhenPaused(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes memory _messageBody
    ) public {
        vm.prank(pauser);
        srcMessageTransmitter.pause();
        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
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
            _recipient,
            messageBody
        );
    }

    function testSendMessage_fuzz(uint32 _destinationDomain, bytes32 _recipient)
        public
    {
        _sendMessage(
            version,
            sourceDomain,
            _destinationDomain,
            sender,
            _recipient,
            messageBody
        );
    }

    function testSendAndReceiveMessage() public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        _receiveMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );
    }

    function testReceiveMessage_fuzz(
        uint32 _version,
        uint32 _sourceDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes memory _messageBody
    ) public {
        _receiveMessage(
            _version,
            _sourceDomain,
            destinationDomain, // static (messageRecipient must be deployed on the destination domain)
            _nonce,
            _sender,
            recipient, // static (recipient must be a valid IMessageRecipient)
            _messageBody
        );
    }

    function testReceiveMessage_rejectInvalidDestinationDomain() public {
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            2,
            nonce,
            sender,
            recipient,
            messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid destination domain");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsNotEnabledSigner() public {
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            messageBody
        );

        uint256[] memory fakeAttesterPrivateKeys = new uint256[](1);
        fakeAttesterPrivateKeys[0] = fakeAttesterPK;
        bytes memory _signature = _signMessage(
            _message,
            fakeAttesterPrivateKeys
        );

        vm.expectRevert(
            "Signature verification failed: signer is not enabled attester"
        );
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_succeedsFor2of3Multisig() public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );

        // setup 2/3 multisig
        destMessageTransmitter.enableAttester(secondAttester);
        destMessageTransmitter.enableAttester(thirdAttester);
        destMessageTransmitter.setSignatureThreshold(2);

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // manually sort attesters in correct order
        attesterPrivateKeys[1] = attesterPK;
        // attester == 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf
        attesterPrivateKeys[0] = secondAttesterPK;
        // second attester = 0x6813eb9362372eef6200f3b1dbc3f819671cba69
        // sanity check order
        assertTrue(attester > secondAttester);
        assertTrue(secondAttester > address(0));
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        // assert that a MessageReceive event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(sourceDomain, _msgNonce, sender, messageBody);

        bool success = destMessageTransmitter.receiveMessage(
            _message,
            _signature
        );
        assertTrue(success);

        // check that the nonce is used
        assertTrue(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(sourceDomain, _msgNonce)
            )
        );
    }

    function testReceiveMessage_rejectsOutOfOrderSigners() public {
        bytes memory _message = _getMessage();

        // setup 2/3 multisig
        destMessageTransmitter.enableAttester(secondAttester);
        destMessageTransmitter.enableAttester(thirdAttester);
        destMessageTransmitter.setSignatureThreshold(2);

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // // manually sort attesters in incorrect order
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = secondAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert(
            "Signature verification failed: signer is out of order or duplicate"
        );
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

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // manually sort attesters in correct order
        attesterPrivateKeys[1] = attesterPK;
        attesterPrivateKeys[0] = secondAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        // reverts because signature length 65 (immutable value) * signatureThreshold 1 (cannot be set to 0) != 0
        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsDuplicateSigners() public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );

        // setup 2/3 multisig
        destMessageTransmitter.enableAttester(secondAttester);
        destMessageTransmitter.enableAttester(thirdAttester);
        destMessageTransmitter.setSignatureThreshold(2);

        uint256[] memory attesterPrivateKeys = new uint256[](2);
        // attempt to use same private key to sign twice (disallowed)
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert(
            "Signature verification failed: signer is out of order or duplicate"
        );
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsTooFewSignatures() public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );

        // add second attester
        destMessageTransmitter.enableAttester(secondAttester);

        // add third attester
        destMessageTransmitter.enableAttester(thirdAttester);

        // require two attesters (2 of 3)
        destMessageTransmitter.setSignatureThreshold(2);

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        // use only 1 key (2 required)
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsTooManySignatures() public {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );

        // add second attester
        destMessageTransmitter.enableAttester(secondAttester);

        // add third attester
        destMessageTransmitter.enableAttester(thirdAttester);

        // require two attesters (2 of 3)
        destMessageTransmitter.setSignatureThreshold(2);

        uint256[] memory attesterPrivateKeys = new uint256[](3);
        // use only 3 key (only 2 allowed)
        attesterPrivateKeys[0] = attesterPK;
        attesterPrivateKeys[1] = secondAttesterPK;
        attesterPrivateKeys[2] = thirdAttesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("Invalid attestation length");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsReusedNonceInSeparateTransaction()
        public
    {
        // successfully receiveMessage
        (bytes memory _message, bytes memory _signature) = _receiveMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            messageBody
        );

        // fail to call receiveMessage again with same nonce
        vm.expectRevert("Nonce already used");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectsReusedNonceInSingleTransactionFromExternalCaller()
        public
    {
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        MockRepeatCaller _mockRepeatCaller = new MockRepeatCaller();

        // fail to call receiveMessage twice in same transaction
        vm.expectRevert("Nonce already used");
        _mockRepeatCaller.callReceiveMessageTwice(
            address(destMessageTransmitter),
            _message,
            _signature
        );
    }

    function testReceiveMessage_rejectsReusedNonceFromReentrantCaller() public {
        MockReentrantCaller _mockReentrantCaller = new MockReentrantCaller();

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            Message.addressToBytes32(address(_mockReentrantCaller)),
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
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _nonce,
            sender,
            recipient,
            "revert"
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        vm.expectRevert("mock revert");
        destMessageTransmitter.receiveMessage(_message, _signature);

        // check that the nonce is not used
        assertFalse(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(sourceDomain, _nonce)
            )
        );
    }

    function testReceiveMessage_revertsIfHandleReceiveMessageReturnsFalse()
        public
    {
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
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
        bytes memory _signature
    ) public {
        vm.prank(pauser);
        srcMessageTransmitter.pause();
        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.receiveMessage(_message, _signature);

        // receiveMessage works again after unpause
        vm.prank(pauser);
        srcMessageTransmitter.unpause();
        uint64 _nonce = srcMessageTransmitter.availableNonces(
            destinationDomain
        );
        _receiveMessage(
            version,
            sourceDomain,
            destinationDomain,
            _nonce,
            sender,
            recipient,
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
        bool _success = _messageTransmitter.sendMessage(
            destinationDomain,
            recipient,
            _messageBody
        );

        assertTrue(_success);
    }

    function testSendMaxMessageBodySize_revertsOnNonOwner(
        uint256 _newMaxMessageBodySize
    ) public {
        expectRevertWithWrongOwner();
        srcMessageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
    }

    function testSetSignatureThreshold_revertsIfCalledByNonAttesterManager()
        public
    {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);
        vm.expectRevert("Attestable: caller is not the attester manager");
        srcMessageTransmitter.setSignatureThreshold(1);
    }

    function testSetSignatureThreshold_succeeds() public {
        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );
        assertEq(_localMessageTransmitter.signatureThreshold(), 1);

        // enable second attester, so increasing threshold is allowed
        _localMessageTransmitter.enableAttester(secondAttester);

        vm.expectEmit(true, true, true, true);
        emit SignatureThresholdUpdated(1, 2);

        // update signatureThreshold to 2
        _localMessageTransmitter.setSignatureThreshold(2);
        assertEq(_localMessageTransmitter.signatureThreshold(), 2);
    }

    function testSetSignatureThreshold_rejectsZeroValue() public {
        vm.expectRevert("New signature threshold must be nonzero");
        srcMessageTransmitter.setSignatureThreshold(0);
    }

    function testSetSignatureThreshold_cannotExceedNumberOfEnabledAttesters()
        public
    {
        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );
        assertEq(_localMessageTransmitter.signatureThreshold(), 1);

        // fail to update signatureThreshold to 2
        vm.expectRevert(
            "New signature threshold cannot exceed the number of enabled attesters"
        );
        _localMessageTransmitter.setSignatureThreshold(2);

        assertEq(_localMessageTransmitter.signatureThreshold(), 1);
    }

    function testSetSignatureThreshold_notEqualToCurrentSignatureThreshold()
        public
    {
        vm.expectRevert(
            "New signature threshold must not equal current signature threshold"
        );
        srcMessageTransmitter.setSignatureThreshold(1);
    }

    function testGetEnabledAttester_succeeds() public {
        assertEq(srcMessageTransmitter.getEnabledAttester(0), attester);
    }

    function testGetEnabledAttester_reverts() public {
        vm.expectRevert("EnumerableSet: index out of bounds");
        srcMessageTransmitter.getEnabledAttester(1);
    }

    function testEnableAttester_succeeds() public {
        address _newAttester = vm.addr(1601);

        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );

        assertFalse(_localMessageTransmitter.isEnabledAttester(_newAttester));

        assertEq(_localMessageTransmitter.getNumEnabledAttesters(), 1);

        vm.expectEmit(true, true, true, true);
        emit AttesterEnabled(_newAttester);
        _localMessageTransmitter.enableAttester(_newAttester);
        assertTrue(_localMessageTransmitter.isEnabledAttester(_newAttester));

        assertEq(_localMessageTransmitter.getNumEnabledAttesters(), 2);
    }

    function testEnableAttester_revertsIfCalledByNonAttesterManager(
        address _addr
    ) public {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);

        vm.expectRevert("Attestable: caller is not the attester manager");
        srcMessageTransmitter.enableAttester(_addr);
    }

    function testEnableAttester_rejectsZeroAddress() public {
        address _newAttesterManager = address(0);
        vm.expectRevert("New attester must be nonzero");
        srcMessageTransmitter.enableAttester(_newAttesterManager);
    }

    function testEnableAttester_returnsFalseIfAttesterAlreadyExists() public {
        vm.expectRevert("Attester already enabled");
        srcMessageTransmitter.enableAttester(attester);
        assertEq(srcMessageTransmitter.getNumEnabledAttesters(), 1);
        assertTrue(srcMessageTransmitter.isEnabledAttester(attester));
    }

    function testDisableAttester_succeeds() public {
        // enable second attester, so disabling is allowed
        srcMessageTransmitter.enableAttester(secondAttester);
        assertEq(srcMessageTransmitter.getNumEnabledAttesters(), 2);

        vm.expectEmit(true, true, true, true);
        emit AttesterDisabled(attester);
        srcMessageTransmitter.disableAttester(attester);
        assertEq(srcMessageTransmitter.getNumEnabledAttesters(), 1);
        assertFalse(srcMessageTransmitter.isEnabledAttester(attester));
    }

    function testDisableAttester_revertsIfCalledByNonAttesterManager() public {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);

        vm.expectRevert("Attestable: caller is not the attester manager");
        srcMessageTransmitter.disableAttester(attester);
    }

    function testDisableAttester_revertsIfOneOrLessAttestersAreEnabled()
        public
    {
        vm.expectRevert(
            "Unable to disable attester because 1 or less attesters are enabled"
        );
        srcMessageTransmitter.disableAttester(attester);
    }

    function testDisableAttester_revertsIfSignatureThresholdTooLow() public {
        srcMessageTransmitter.enableAttester(secondAttester);
        srcMessageTransmitter.setSignatureThreshold(2);

        vm.expectRevert(
            "Unable to disable attester because signature threshold is too low"
        );
        srcMessageTransmitter.disableAttester(attester);
    }

    function testDisableAttester_revertsIfAttesterAlreadyDisabled() public {
        address _nonAttester = vm.addr(1603);
        // enable second attester, so disabling is allowed
        srcMessageTransmitter.enableAttester(secondAttester);

        vm.expectRevert("Attester already disabled");
        srcMessageTransmitter.disableAttester(_nonAttester);
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

    function testTransferOwnership() public {
        address _newOwner = vm.addr(1509);
        transferOwnership(address(srcMessageTransmitter), _newOwner);
    }

    /**
     * @notice hashes `_source` and `_nonce`.
     * @param _source Domain of chain where the transfer originated
     * @param _nonce The unique identifier for the message from source to
              destination
     * @return Returns hash of source and nonce
     */
    function _hashSourceAndNonce(uint32 _source, uint256 _nonce)
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
        uint64 _nonce = srcMessageTransmitter.availableNonces(
            _destinationDomain
        );

        bytes memory _expectedMessage = Message.formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _messageBody
        );

        // assert that a MessageSent event was logged with expected message bytes
        vm.prank(Message.bytes32ToAddress(_sender));
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);
        bool _success = srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _messageBody
        );

        assertTrue(_success);

        // assert availableNonces was updated
        uint256 _incrementedNonce = srcMessageTransmitter.availableNonces(
            _destinationDomain
        );

        assertEq(_incrementedNonce, uint256(_nonce + 1));

        return _nonce;
    }

    function _receiveMessage(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes memory _messageBody
    ) internal returns (bytes memory, bytes memory) {
        bytes memory _message = Message.formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _messageBody
        );

        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        bytes memory _signature = _signMessage(_message, attesterPrivateKeys);

        // assert that a MessageReceive event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageReceived(_sourceDomain, _nonce, _sender, _messageBody);

        bool success = destMessageTransmitter.receiveMessage(
            _message,
            _signature
        );
        assertTrue(success);

        // check that the nonce is used
        assertTrue(
            destMessageTransmitter.usedNonces(
                _hashSourceAndNonce(_sourceDomain, _nonce)
            )
        );

        return (_message, _signature);
    }

    // ============ Internal: Utils ============
    function _signMessage(bytes memory _message, uint256[] memory _privKeys)
        internal
        returns (bytes memory)
    {
        bytes memory _signaturesConcatenated = "";

        for (uint256 i = 0; i < _privKeys.length; i++) {
            uint256 _privKey = _privKeys[i];
            bytes32 _digest = keccak256(_message);
            (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_privKey, _digest);
            bytes memory _signature = abi.encodePacked(_r, _s, _v);

            _signaturesConcatenated = abi.encodePacked(
                _signaturesConcatenated,
                _signature
            );
        }

        return _signaturesConcatenated;
    }

    function _getMessage() internal returns (bytes memory) {
        uint64 _msgNonce = _sendMessage(
            version,
            sourceDomain,
            destinationDomain,
            sender,
            recipient,
            messageBody
        );

        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _msgNonce,
            sender,
            recipient,
            messageBody
        );
    }
}
