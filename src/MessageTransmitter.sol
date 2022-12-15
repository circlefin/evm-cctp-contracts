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

import "@memview-sol/contracts/TypedMemView.sol";
import "./interfaces/IMessageTransmitter.sol";
import "./interfaces/IMessageHandler.sol";
import "./messages/Message.sol";
import "./roles/Pausable.sol";
import "./roles/Rescuable.sol";
import "./roles/Attestable.sol";

/**
 * @title MessageTransmitter
 * @notice Contract responsible for sending and receiving messages across chains.
 */
contract MessageTransmitter is
    IMessageTransmitter,
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

    // ============ State Variables ============
    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // Message Format version
    uint32 public immutable version;

    // Maximum size of message body, in bytes.
    // This value is set by owner.
    uint256 public maxMessageBodySize;

    // Next available nonce from this source domain
    uint64 public nextAvailableNonce;

    // Maps a bytes32 hash of (sourceDomain, nonce) -> uint256 (0 if unused, 1 if used)
    mapping(bytes32 => uint256) public usedNonces;

    // ============ Constructor ============
    constructor(
        uint32 _localDomain,
        address _attester,
        uint32 _maxMessageBodySize,
        uint32 _version
    ) Attestable(_attester) {
        localDomain = _localDomain;
        maxMessageBodySize = _maxMessageBodySize;
        version = _version;
    }

    // ============ External Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * @param destinationDomain Domain of destination chain
     * @param recipient Address of message recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message
     * @return nonce reserved by message
     */
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external override whenNotPaused returns (uint64) {
        bytes32 _emptyDestinationCaller = bytes32(0);
        uint64 _nonce = _reserveAndIncrementNonce();
        bytes32 _messageSender = Message.addressToBytes32(msg.sender);

        _sendMessage(
            destinationDomain,
            recipient,
            _emptyDestinationCaller,
            _messageSender,
            _nonce,
            messageBody
        );

        return _nonce;
    }

    /**
     * @notice Replace a message with a new message body and/or destination caller.
     * @dev The `originalAttestation` must be a valid attestation of `originalMessage`.
     * Reverts if msg.sender does not match sender of original message, or if the source domain of the original message
     * does not match this MessageTransmitter's local domain.
     * @param originalMessage original message to replace
     * @param originalAttestation attestation of `originalMessage`
     * @param newMessageBody new message body of replaced message
     * @param newDestinationCaller the new destination caller, which may be the
     * same as the original destination caller, a new destination caller, or an empty
     * destination caller (bytes32(0), indicating that any destination caller is valid.)
     */
    function replaceMessage(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes calldata newMessageBody,
        bytes32 newDestinationCaller
    ) external override whenNotPaused {
        // Validate each signature in the attestation
        _verifyAttestationSignatures(originalMessage, originalAttestation);

        bytes29 _originalMsg = originalMessage.ref(0);

        // Validate message format
        _originalMsg._validateMessageFormat();

        // Validate message sender
        bytes32 _sender = _originalMsg._sender();
        require(
            msg.sender == Message.bytes32ToAddress(_sender),
            "Sender not permitted to use nonce"
        );

        // Validate source domain
        uint32 _sourceDomain = _originalMsg._sourceDomain();
        require(
            _sourceDomain == localDomain,
            "Message not originally sent from this domain"
        );

        uint32 _destinationDomain = _originalMsg._destinationDomain();
        bytes32 _recipient = _originalMsg._recipient();
        uint64 _nonce = _originalMsg._nonce();

        _sendMessage(
            _destinationDomain,
            _recipient,
            newDestinationCaller,
            _sender,
            _nonce,
            newMessageBody
        );
    }

    /**
     * @notice Send the message to the destination domain and recipient, for a specified `destinationCaller` on the
     * destination domain.
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * WARNING: if the `destinationCaller` does not represent a valid address, then it will not be possible
     * to broadcast the message on the destination domain. This is an advanced feature, and the standard
     * sendMessage() should be preferred for use cases where a specific destination caller is not required.
     * @param destinationDomain Domain of destination chain
     * @param recipient Address of message recipient on destination domain as bytes32
     * @param destinationCaller caller on the destination domain, as bytes32
     * @param messageBody Raw bytes content of message
     * @return nonce reserved by message
     */
    function sendMessageWithCaller(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 destinationCaller,
        bytes calldata messageBody
    ) external override whenNotPaused returns (uint64) {
        require(
            destinationCaller != bytes32(0),
            "Destination caller must be nonzero"
        );

        uint64 _nonce = _reserveAndIncrementNonce();
        bytes32 _messageSender = Message.addressToBytes32(msg.sender);

        _sendMessage(
            destinationDomain,
            recipient,
            destinationCaller,
            _messageSender,
            _nonce,
            messageBody
        );

        return _nonce;
    }

    /**
     * @notice Receive a message. Messages with a given nonce
     * can only be broadcast once for a (sourceDomain, destinationDomain)
     * pair. The message body of a valid message is passed to the
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
     * Message format:
     * Field                 Bytes      Type       Index
     * version               4          uint32     0
     * sourceDomain          4          uint32     4
     * destinationDomain     4          uint32     8
     * nonce                 8          uint64     12
     * sender                32         bytes32    20
     * recipient             32         bytes32    52
     * messageBody           dynamic    bytes      84
     * @param message Message bytes
     * @param attestation Concatenated 65-byte signature(s) of `message`, in increasing order
     * of the attester address recovered from signatures.
     * @return success bool, true if successful
     */
    function receiveMessage(bytes calldata message, bytes calldata attestation)
        external
        override
        whenNotPaused
        returns (bool success)
    {
        // Validate each signature in the attestation
        _verifyAttestationSignatures(message, attestation);

        bytes29 _msg = message.ref(0);

        // Validate message format
        _msg._validateMessageFormat();

        // Validate domain
        require(
            _msg._destinationDomain() == localDomain,
            "Invalid destination domain"
        );

        // Validate destination caller
        if (_msg._destinationCaller() != bytes32(0)) {
            require(
                _msg._destinationCaller() ==
                    Message.addressToBytes32(msg.sender),
                "Invalid caller for message"
            );
        }

        // Validate version
        require(_msg._version() == version, "Invalid message version");

        // Validate nonce is available
        uint32 _sourceDomain = _msg._sourceDomain();
        uint64 _nonce = _msg._nonce();
        bytes32 _sourceAndNonce = _hashSourceAndNonce(_sourceDomain, _nonce);
        require(usedNonces[_sourceAndNonce] == 0, "Nonce already used");
        // Mark nonce used
        usedNonces[_sourceAndNonce] = 1;

        // Handle receive message
        bytes32 _sender = _msg._sender();
        bytes memory _messageBody = _msg._messageBody().clone();
        require(
            IMessageHandler(Message.bytes32ToAddress(_msg._recipient()))
                .handleReceiveMessage(_sourceDomain, _sender, _messageBody),
            "handleReceiveMessage() failed"
        );

        // Emit MessageReceived event
        emit MessageReceived(
            msg.sender,
            _sourceDomain,
            _nonce,
            _sender,
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
    function setMaxMessageBodySize(uint256 newMaxMessageBodySize)
        external
        onlyOwner
    {
        maxMessageBodySize = newMaxMessageBodySize;
        emit MaxMessageBodySizeUpdated(maxMessageBodySize);
    }

    // ============ Internal Utils ============
    /**
     * @notice Send the message to the destination domain and recipient. If `_destinationCaller` is not equal to bytes32(0),
     * the message can only be received on the destination chain when called by `_destinationCaller`.
     * @dev Format the message and emit `MessageSent` event with message information.
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of message recipient on destination domain as bytes32
     * @param _destinationCaller caller on the destination domain, as bytes32
     * @param _sender message sender, as bytes32
     * @param _nonce nonce reserved for message
     * @param _messageBody Raw bytes content of message
     */
    function _sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        bytes32 _sender,
        uint64 _nonce,
        bytes calldata _messageBody
    ) internal {
        // Validate message body length
        require(
            _messageBody.length <= maxMessageBodySize,
            "Message body exceeds max size"
        );

        require(_recipient != bytes32(0), "Recipient must be nonzero");

        // serialize message
        bytes memory _message = Message._formatMessage(
            version,
            localDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        // Emit MessageSent event
        emit MessageSent(_message);
    }

    /**
     * @notice hashes `_source` and `_nonce`.
     * @param _source Domain of chain where the transfer originated
     * @param _nonce The unique identifier for the message from source to
              destination
     * @return hash of source and nonce
     */
    function _hashSourceAndNonce(uint32 _source, uint64 _nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_source, _nonce));
    }

    /**
     * Reserve and increment next available nonce
     * @return nonce reserved
     */
    function _reserveAndIncrementNonce() internal returns (uint64) {
        uint64 _nonceReserved = nextAvailableNonce;
        nextAvailableNonce = nextAvailableNonce + 1;
        return _nonceReserved;
    }
}
