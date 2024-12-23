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
import {BaseMessageTransmitter} from "./BaseMessageTransmitter.sol";
import {MessageV2} from "../messages/v2/MessageV2.sol";
import {AddressUtils} from "../messages/v2/AddressUtils.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {IMessageHandlerV2} from "../interfaces/v2/IMessageHandlerV2.sol";
import {FINALITY_THRESHOLD_FINALIZED} from "./FinalityThresholds.sol";

/**
 * @title MessageTransmitterV2
 * @notice Contract responsible for sending and receiving messages across chains.
 */
contract MessageTransmitterV2 is IMessageTransmitterV2, BaseMessageTransmitter {
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

    // ============ Libraries ============
    using AddressUtils for address;
    using AddressUtils for address payable;
    using AddressUtils for bytes32;
    using MessageV2 for bytes29;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // ============ Constructor ============
    /**
     * @param _localDomain Domain of chain on which the contract is deployed
     * @param _version Message Format version
     */
    constructor(
        uint32 _localDomain,
        uint32 _version
    ) BaseMessageTransmitter(_localDomain, _version) {
        _disableInitializers();
    }

    // ============ Initializers ============
    /**
     * @notice Initializes the contract
     * @dev Owner, pauser, rescuer, attesterManager, and attesters must be non-zero.
     * @dev Signature threshold must be non-zero, but not exceed the number of enabled attesters
     * @param owner_ Owner address
     * @param pauser_ Pauser address
     * @param rescuer_ Rescuer address
     * @param attesterManager_ AttesterManager address
     * @param attesters_ Set of attesters to enable
     * @param signatureThreshold_ Signature threshold
     * @param maxMessageBodySize_ Maximum message body size
     */
    function initialize(
        address owner_,
        address pauser_,
        address rescuer_,
        address attesterManager_,
        address[] calldata attesters_,
        uint256 signatureThreshold_,
        uint256 maxMessageBodySize_
    ) external initializer {
        require(owner_ != address(0), "Owner is the zero address");
        require(
            attesterManager_ != address(0),
            "AttesterManager is the zero address"
        );
        require(
            signatureThreshold_ <= attesters_.length,
            "Signature threshold exceeds attesters"
        );
        require(maxMessageBodySize_ > 0, "MaxMessageBodySize is zero");

        // Roles
        _transferOwnership(owner_);
        _updateRescuer(rescuer_);
        _updatePauser(pauser_);
        _setAttesterManager(attesterManager_);

        // Max message body size
        _setMaxMessageBodySize(maxMessageBodySize_);

        // Attester configuration
        uint256 _attestersLength = attesters_.length;
        for (uint256 i; i < _attestersLength; ++i) {
            _enableAttester(attesters_[i]);
        }

        // Signature threshold
        _setSignatureThreshold(signatureThreshold_);

        // Claim 0-nonce
        usedNonces[bytes32(0)] = NONCE_USED;
    }

    // ============ External Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Formats the message, and emits a `MessageSent` event with message information.
     * @param destinationDomain Domain of destination chain
     * @param recipient Address of message recipient on destination chain as bytes32
     * @param destinationCaller Caller on the destination domain, as bytes32
     * @param minFinalityThreshold The minimum finality at which the message should be attested to
     * @param messageBody Contents of the message (bytes)
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

        bytes32 _messageSender = msg.sender.toBytes32();

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
     * The message body of a valid message is passed to the specified recipient for further processing.
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
     * @return success True, if successful; false, if not
     */
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override whenNotPaused returns (bool success) {
        // Validate message
        (
            bytes32 _nonce,
            uint32 _sourceDomain,
            bytes32 _sender,
            address _recipient,
            uint32 _finalityThresholdExecuted,
            bytes memory _messageBody
        ) = _validateReceivedMessage(message, attestation);

        // Mark nonce as used
        usedNonces[_nonce] = NONCE_USED;

        // Handle receive message
        if (_finalityThresholdExecuted < FINALITY_THRESHOLD_FINALIZED) {
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
     * @notice Validates a received message, including the attestation signatures as well
     * as the message contents.
     * @param _message Message bytes
     * @param _attestation Concatenated 65-byte signature(s) of `message`
     * @return _nonce Message nonce, as bytes32
     * @return _sourceDomain Domain where message originated from
     * @return _sender Sender of the message
     * @return _recipient Recipient of the message
     * @return _finalityThresholdExecuted The level of finality at which the message was attested to
     * @return _messageBody The message body bytes
     */
    function _validateReceivedMessage(
        bytes calldata _message,
        bytes calldata _attestation
    )
        internal
        view
        returns (
            bytes32 _nonce,
            uint32 _sourceDomain,
            bytes32 _sender,
            address _recipient,
            uint32 _finalityThresholdExecuted,
            bytes memory _messageBody
        )
    {
        // Validate each signature in the attestation
        _verifyAttestationSignatures(_message, _attestation);

        bytes29 _msg = _message.ref(0);

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
                _msg._getDestinationCaller() == msg.sender.toBytes32(),
                "Invalid caller for message"
            );
        }

        // Validate version
        require(_msg._getVersion() == version, "Invalid message version");

        // Validate nonce is available
        _nonce = _msg._getNonce();
        require(usedNonces[_nonce] == 0, "Nonce already used");

        // Unpack remaining values
        _sourceDomain = _msg._getSourceDomain();
        _sender = _msg._getSender();
        _recipient = _msg._getRecipient().toAddress();
        _finalityThresholdExecuted = _msg._getFinalityThresholdExecuted();
        _messageBody = _msg._getMessageBody().clone();
    }
}
