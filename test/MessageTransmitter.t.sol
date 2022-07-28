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
import "./MockCircleBridge.sol";
import "./MockReentrantCaller.sol";
import "./MockRepeatCaller.sol";
import "../src/interfaces/IReceiver.sol";
import "../src/MessageTransmitter.sol";
import "../lib/forge-std/src/Test.sol";

contract MessageTransmitterTest is Test {
    MessageTransmitter messageTransmitter;
    MockCircleBridge mockCircleBridge;
    MockReentrantCaller mockReentrantCaller;

    uint32 sourceDomain = 0;
    uint32 destinationDomain = 1;
    uint32 version = 1;
    uint32 nonce = 99;
    bytes32 recipient;
    bytes32 sender = bytes32(uint256(uint160(address(vm.addr(1505)))));
    bytes messageBody = bytes("test message");
    uint256 attesterPK = 1;
    uint256 fakeAttesterPK = 2;
    address attester = vm.addr(attesterPK);
    address fakeAttester = vm.addr(fakeAttesterPK);

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

    function setUp() public {
        messageTransmitter = new MessageTransmitter(
            destinationDomain,
            attester
        );
        mockCircleBridge = new MockCircleBridge();
        recipient = bytes32(uint256(uint160(address(mockCircleBridge))));
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
        messageTransmitter.receiveMessage(_message, _signature);
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
        messageTransmitter.receiveMessage(_message, _signature);
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
        messageTransmitter.receiveMessage(_message, _signature);
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
            address(messageTransmitter),
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
            addressToBytes32(address(_mockReentrantCaller)),
            bytes("reenter")
        );

        bytes memory _signature = _signMessage(_message, attesterPK);

        _mockReentrantCaller.setMessageAndSignature(_message, _signature);

        // fail to call receiveMessage twice in same transaction
        vm.expectRevert("Re-entrant call failed due to reused nonce");
        messageTransmitter.receiveMessage(_message, _signature);
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
        messageTransmitter.receiveMessage(_message, _signature);

        // check that the nonce is not used
        assertFalse(
            messageTransmitter.usedNonces(
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
        messageTransmitter.receiveMessage(_message, _signature);
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

        bool success = messageTransmitter.receiveMessage(_message, _signature);
        assertTrue(success);

        // check that the nonce is used
        assertTrue(
            messageTransmitter.usedNonces(
                _hashSourceAndNonce(_sourceDomain, _nonce)
            )
        );

        return (_message, _signature);
    }

    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
