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

import {IMessageTransmitterV2} from "../interfaces/v2/IMessageTransmitterV2.sol";
import {Attestable} from "../roles/Attestable.sol";
import {Pausable} from "../roles/Pausable.sol";
import {Rescuable} from "../roles/Rescuable.sol";
import {MessageV2} from "../messages/v2/MessageV2.sol";
import {AddressUtils} from "../messages/v2/AddressUtils.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {IMessageHandlerV2} from "../interfaces/v2/IMessageHandlerV2.sol";

/**
 * @title MessageTransmitterV2
 * @notice Contract responsible for sending and receiving messages across chains.
 */
// TODO STABLE-6894 & STABLE-STABLE-7293: refactor inheritance
// as-needed to work with Proxy pattern.
contract MessageTransmitterV2 is
    IMessageTransmitterV2,
    Pausable,
    Rescuable,
    Attestable
{
    // ============ Events ============
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
     * @param finalityThresholdExecuted The finality at which message was attested to
     * @param messageBody message body bytes
     */
    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        bytes32 indexed nonce,
        bytes32 sender,
        uint32 indexed finalityThresholdExecuted,
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
    using MessageV2 for bytes29;

    // ============ State Variables ============
    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // Message Format version
    uint32 public immutable version;

    // The threshold at which messages are considered finalized
    uint32 public immutable finalizedMessageThreshold = 2000;

    // Maximum size of message body, in bytes.
    // This value is set by owner.
    uint256 public maxMessageBodySize;

    // Maps a bytes32 nonce -> uint256 (0 if unused, 1 if used)
    mapping(bytes32 => uint256) public usedNonces;

    // ============ Constructor ============
    // TODO STABLE-6894 & STABLE-STABLE-7293: refactor constructor
    // as-needed to work with Proxy pattern.
    constructor(
        uint32 _localDomain,
        address _attester,
        uint32 _maxMessageBodySize,
        uint32 _version
    ) Attestable(_attester) {
        localDomain = _localDomain;
        version = _version;
        maxMessageBodySize = _maxMessageBodySize;
    }

    // ============ External Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Formats the message, and emit `MessageSent` event with message information.
     * @param destinationDomain Domain of destination chain
     * @param recipient Address of message recipient on destination chain as bytes32
     * @param destinationCaller caller on the destination domain, as bytes32
     * @param minFinalityThreshold the minimum finality at which the message should be attested to
     * @param messageBody raw bytes content of message
     */
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 destinationCaller,
        uint32 minFinalityThreshold,
        bytes calldata messageBody
    ) external override whenNotPaused {
        require(destinationDomain != localDomain, "Domain is local domain");
        // Validate message body length
        require(
            messageBody.length <= maxMessageBodySize,
            "Message body exceeds max size"
        );
        require(recipient != bytes32(0), "Recipient must be nonzero");

        bytes32 _messageSender = AddressUtils.addressToBytes32(msg.sender);

        // serialize message
        bytes memory _message = MessageV2._formatMessageForRelay(
            version,
            localDomain,
            destinationDomain,
            _messageSender,
            recipient,
            destinationCaller,
            minFinalityThreshold,
            messageBody
        );

        // Emit MessageSent event
        emit MessageSent(_message);
    }

    /**
     * @notice Receive a message. Messages can only be broadcast once for a given nonce.
     * The message body of a valid message is passed to the
     * specified recipient for further processing.
     *
     * @dev Attestation format:
     * A valid attestation is the concatenated 65-byte signature(s) of exactly
     * `thresholdSignature` signatures, in increasing order of attester address.
     * ***If the attester addresses recovered from signatures are not in
     * increasing order, signature verification will fail.***
     * If incorrect number of signatures or duplicate signatures are supplied,
     * signature verification will fail.
     *
     * Message Format:
     *
     * Field                        Bytes      Type       Index
     * version                      4          uint32     0
     * sourceDomain                 4          uint32     4
     * destinationDomain            4          uint32     8
     * nonce                        32         bytes32    12
     * sender                       32         bytes32    44
     * recipient                    32         bytes32    76
     * destinationCaller            32         bytes32    108
     * minFinalityThreshold         4          uint32     140
     * finalityThresholdExecuted    4          uint32     144
     * messageBody                  dynamic    bytes      148
     * @param message Message bytes
     * @param attestation Concatenated 65-byte signature(s) of `message`, in increasing order
     * of the attester address recovered from signatures.
     * @return success bool, true if successful
     */
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override whenNotPaused returns (bool success) {
        // Validate each signature in the attestation
        _verifyAttestationSignatures(message, attestation);

        bytes29 _msg = message.ref(0);

        // Validate message format
        _msg._validateMessageFormat();

        // Validate domain
        require(
            _msg._getDestinationDomain() == localDomain,
            "Invalid destination domain"
        );

        // Validate destination caller
        if (_msg._getDestinationCaller() != bytes32(0)) {
            require(
                _msg._getDestinationCaller() ==
                    AddressUtils.addressToBytes32(msg.sender),
                "Invalid caller for message"
            );
        }

        // Validate version
        require(_msg._getVersion() == version, "Invalid message version");

        // Validate nonce is available
        bytes32 _nonce = _msg._getNonce();
        require(usedNonces[_nonce] == 0, "Nonce already used");
        // Mark nonce used
        usedNonces[_nonce] = 1;

        // Unpack remaining values
        uint32 _sourceDomain = _msg._getSourceDomain();
        bytes32 _sender = _msg._getSender();
        address _recipient = AddressUtils.bytes32ToAddress(
            _msg._getRecipient()
        );
        uint32 _finalityThresholdExecuted = _msg
            ._getFinalityThresholdExecuted();
        bytes memory _messageBody = _msg._getMessageBody().clone();

        // Handle receive message
        if (_finalityThresholdExecuted < finalizedMessageThreshold) {
            require(
                IMessageHandlerV2(_recipient).handleReceiveUnfinalizedMessage(
                    _sourceDomain,
                    _sender,
                    _finalityThresholdExecuted,
                    _messageBody
                ),
                "handleReceiveUnfinalizedMessage() failed"
            );
        } else {
            require(
                IMessageHandlerV2(_recipient).handleReceiveFinalizedMessage(
                    _sourceDomain,
                    _sender,
                    _finalityThresholdExecuted,
                    _messageBody
                ),
                "handleReceiveFinalizedMessage() failed"
            );
        }

        // Emit MessageReceived event
        emit MessageReceived(
            msg.sender,
            _sourceDomain,
            _nonce,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );

        return true;
    }

    /**
     * @notice Sets the max message body size
     * @dev This value should not be reduced without good reason,
     * to avoid impacting users who rely on large messages.
     * @param newMaxMessageBodySize new max message body size, in bytes
     */
    function setMaxMessageBodySize(
        uint256 newMaxMessageBodySize
    ) external onlyOwner {
        maxMessageBodySize = newMaxMessageBodySize;
        emit MaxMessageBodySizeUpdated(maxMessageBodySize);
    }

    // ============ Internal Utils ============
}
