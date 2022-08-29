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
    address attester = vm.addr(attesterPK);
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

        bytes memory _signature = _signMessage(_message, attesterPK);

        vm.expectRevert("Invalid destination domain");
        destMessageTransmitter.receiveMessage(_message, _signature);
    }

    function testReceiveMessage_rejectInvalidSignature() public {
        bytes memory _message = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            nonce,
            sender,
            recipient,
            messageBody
        );

        bytes memory _signature = _signMessage(_message, fakeAttesterPK);

        vm.expectRevert("Invalid attester signature");
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

        bytes memory _signature = _signMessage(_message, attesterPK);

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

        bytes memory _signature = _signMessage(_message, attesterPK);

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

        bytes memory _signature = _signMessage(_message, attesterPK);

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

        bytes memory _signature = _signMessage(_message, attesterPK);

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

    // ============ Internal: Utils ============
    function _signMessage(bytes memory _message, uint256 _privKey)
        internal
        returns (bytes memory)
    {
        bytes32 _digest = keccak256(_message);
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_privKey, _digest);
        bytes memory _signature = abi.encodePacked(_r, _s, _v);
        return _signature;
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

        bytes memory _signature = _signMessage(_message, attesterPK);

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
}
