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

import "@memview-sol/contracts/TypedMemView.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./interfaces/IReceiver.sol";
import "./interfaces/IRelayer.sol";
import "./interfaces/IMessageDestinationHandler.sol";
import "./Message.sol";

/**
 * @title MessageTransmitter
 * @notice Contract responsible for sending and receiving messages across chains.
 */
contract MessageTransmitter is IRelayer, IReceiver {
    // ============ Events ============
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

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;

    // ============ Public Variables ============
    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;
    // Maps a hash of (sourceDomain, nonce) -> boolean
    // boolean value is true if nonce is used
    mapping(bytes32 => bool) public usedNonces;
    // message signer
    address public attester;

    // ============ Constructor ============
    constructor(uint32 _localDomain, address _attester) {
        localDomain = _localDomain;
        // [BRAAV-11992] TODO refactor once role reassignment is supported
        attester = _attester;
    }

    // ============ Public Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * @param _destinationDomain Domain of destination chain
     * @param recipient Address of message recipient on destination chain as bytes32
     * @param _messageBody Raw bytes content of message
     * @return success bool, true if successful
     */
    function sendMessage(
        uint32 _destinationDomain,
        bytes32 recipient,
        bytes memory _messageBody
    )
        external
        override
        returns (bool success)
    // [BRAAV-11741] TODO whenNotPaused (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5fbf494511fd522b931f7f92e2df87d671ea8b0b/contracts/security/Pausable.sol)
    {
        // Emit MessageSent event
        emit MessageSent(bytes("foo"));
    }

    /**
     * @notice Receive a message. Messages with a given nonce
     * can only be broadcast once for a (sourceDomain, destinationDomain)
     * pair. The message body of a valid message is passed to the
     * specified recipient for further processing.
     * @dev Message format:
     * Field                 Bytes      Type       Index
     * version               4          uint32     0
     * sourceDomain          4          uint32     4
     * destinationDomain     4          uint32     8
     * nonce                 8          uint64     12
     * sender                32         bytes32    20
     * recipient             32         bytes32    52
     * messageBody           dynamic    bytes      84
     * @param _message Message bytes
     * @param _signature Signature of message
     * @return success bool, true if successful
     */
    function receiveMessage(bytes memory _message, bytes memory _signature)
        external
        override
        returns (bool success)
    // [BRAAV-11741] TODO whenNotPaused (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5fbf494511fd522b931f7f92e2df87d671ea8b0b/contracts/security/Pausable.sol)
    {
        bytes29 _m = _message.ref(0);

        // Validate domain
        require(
            _m.destinationDomain() == localDomain,
            "Invalid destination domain"
        );

        // Validate attester signature
        require(
            _isAttesterSignature(_message, _signature),
            "Invalid attester signature"
        );

        // Validate nonce is available
        uint32 _sourceDomain = _m.sourceDomain();
        uint64 _nonce = _m.nonce();
        bytes32 _sourceAndNonce = _hashSourceAndNonce(_sourceDomain, _nonce);
        require(!usedNonces[_sourceAndNonce], "Nonce already used");
        // Mark nonce used
        usedNonces[_sourceAndNonce] = true;

        // Handle receive message
        bytes32 _sender = _m.sender();
        bytes memory _messageBody = _m.messageBody().clone();
        require(
            IMessageDestinationHandler(_m.recipientAddress())
                .handleReceiveMessage(_sourceDomain, _sender, _messageBody),
            "handleReceiveMessage() failed"
        );

        // Emit MessageReceived event
        emit MessageReceived(_sourceDomain, _nonce, _sender, _messageBody);
        return true;
    }

    // ============ Internal Utils ============
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

    /**
     * @notice Checks that signature was signed by attester
     * @param _message unsigned message bytes
     * @param _signature message signature
     * @return true iff signature is signed by the attester
     **/
    function _isAttesterSignature(
        bytes memory _message,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 _digest = keccak256(_message);
        return (ECDSA.recover(_digest, _signature) == attester);
    }
}
