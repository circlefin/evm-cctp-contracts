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
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/IMessageTransmitter.sol";
import "./interfaces/IMessageDestinationHandler.sol";
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

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============ State Variables ============
    // Maximum size of message body, in bytes.
    // This value is set by owner.
    uint256 public maxMessageBodySize;

    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // Maps domain -> next available sequential nonce
    mapping(uint32 => uint64) public availableNonces;

    // Maps a hash of (sourceDomain, nonce) -> boolean
    // boolean value is true if nonce is used
    mapping(bytes32 => bool) public usedNonces;

    // number of signatures from distinct attesters required for a message to be received (m in m/n multisig)
    uint256 public signatureThreshold;

    // message format version
    uint32 public version;

    // 65-byte ECDSA signature: v (32) + r (32) + s (1)
    uint256 internal immutable signatureLength = 65;

    // enabled attesters (message signers)
    // (length of enabledAttesters is n in m/n multisig of message signers)
    EnumerableSet.AddressSet private enabledAttesters;

    // ============ Constructor ============
    constructor(
        uint32 _localDomain,
        address _attester,
        uint32 _maxMessageBodySize,
        uint32 _version
    ) {
        localDomain = _localDomain;
        maxMessageBodySize = _maxMessageBodySize;
        version = _version;
        // Initially 1 signature is required. Threshold can be increased by attesterManager.
        signatureThreshold = 1;
        enableAttester(_attester);
    }

    // ============ External Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of message recipient on destination chain as bytes32
     * @param _messageBody Raw bytes content of message
     * @return success bool, true if successful
     */
    function sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes memory _messageBody
    ) external override whenNotPaused returns (bool success) {
        // Validate message body length
        require(
            _messageBody.length <= maxMessageBodySize,
            "Message body exceeds max size"
        );

        // Reserve a nonce for destination domain
        uint64 _nonce = availableNonces[_destinationDomain];

        // Increment nonce
        availableNonces[_destinationDomain] = _nonce + 1;

        // serialize message
        bytes memory _message = Message.formatMessage(
            version,
            localDomain,
            _destinationDomain,
            _nonce,
            Message.addressToBytes32(msg.sender),
            _recipient,
            _messageBody
        );

        // Emit MessageSent event
        emit MessageSent(_message);
        return true;
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
     * @param _message Message bytes
     * @param _attestation Concatenated 65-byte signature(s) of `_message`, in increasing order
     * of the attester address recovered from signatures.
     * @return success bool, true if successful
     */
    function receiveMessage(bytes memory _message, bytes calldata _attestation)
        external
        override
        whenNotPaused
        returns (bool success)
    {
        // Validate each signature in the attestation
        _verifyAttestationSignatures(_message, _attestation);

        bytes29 _m = _message.ref(0);

        // Validate domain
        require(
            _m.destinationDomain() == localDomain,
            "Invalid destination domain"
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

    /**
     * @notice Sets the max message body size
     * @dev This value should not be reduced without good reason,
     * to avoid impacting users who rely on large messages.
     * @param _newMaxMessageBodySize new max message body size, in bytes
     */
    function setMaxMessageBodySize(uint256 _newMaxMessageBodySize)
        external
        onlyOwner
    {
        maxMessageBodySize = _newMaxMessageBodySize;
        emit MaxMessageBodySizeUpdated(maxMessageBodySize);
    }

    /**
     * @notice Enables an attester
     * @dev Only callable by attesterManager. New attester must be nonzero, and currently disabled.
     * @param _newAttester attester to enable
     */
    function enableAttester(address _newAttester) public onlyAttesterManager {
        require(_newAttester != address(0), "New attester must be nonzero");
        require(enabledAttesters.add(_newAttester), "Attester already enabled");
        emit AttesterEnabled(_newAttester);
    }

    /**
     * @notice Disables an attester
     * @dev Only callable by attesterManager. Disabling the attester is not allowed if there is only one attester
     * enabled, or if it would cause the number of enabled attesters to become less than signatureThreshold.
     * (Attester must be currently enabled.)
     * @param _attester attester to disable
     */
    function disableAttester(address _attester) external onlyAttesterManager {
        // Disallow disabling attester if there is only 1 active attester
        require(
            enabledAttesters.length() > 1,
            "Unable to disable attester because 1 or less attesters are enabled"
        );

        // Disallow disabling an attester if it would cause the n in m/n multisig to fall below m (threshold # of signers).
        require(
            enabledAttesters.length() > signatureThreshold,
            "Unable to disable attester because signature threshold is too low"
        );

        require(
            enabledAttesters.remove(_attester),
            "Attester already disabled"
        );
        emit AttesterDisabled(_attester);
    }

    /**
     * @notice Sets the threshold of signatures required to attest to a message.
     * (This is the m in m/n multisig.)
     * @dev new signature threshold must be nonzero, and must not exceed number
     * of enabled attesters.
     * @param _newSignatureThreshold new signature threshold
     */
    function setSignatureThreshold(uint256 _newSignatureThreshold)
        external
        onlyAttesterManager
    {
        require(
            _newSignatureThreshold != 0,
            "New signature threshold must be nonzero"
        );

        require(
            _newSignatureThreshold <= enabledAttesters.length(),
            "New signature threshold cannot exceed the number of enabled attesters"
        );

        require(
            _newSignatureThreshold != signatureThreshold,
            "New signature threshold must not equal current signature threshold"
        );

        uint256 _oldSignatureThreshold = signatureThreshold;
        signatureThreshold = _newSignatureThreshold;
        emit SignatureThresholdUpdated(
            _oldSignatureThreshold,
            signatureThreshold
        );
    }

    /**
     * @notice returns true if given `_attester` is enabled, else false
     * @return true if given `_attester` is enabled, else false
     */
    function isEnabledAttester(address _attester) external view returns (bool) {
        return enabledAttesters.contains(_attester);
    }

    /**
     * @notice returns the number of enabled attesters
     * @return number of enabled attesters
     */
    function getNumEnabledAttesters() external view returns (uint256) {
        return enabledAttesters.length();
    }

    /**
     * @notice gets enabled attester at given `_index`
     * @param _index index of attester to check
     * @return enabled attester at given `_index`
     */
    function getEnabledAttester(uint256 _index)
        external
        view
        returns (address)
    {
        return enabledAttesters.at(_index);
    }

    // ============ Internal Utils ============
    /**
     * @notice hashes `_source` and `_nonce`.
     * @param _source Domain of chain where the transfer originated
     * @param _nonce The unique identifier for the message from source to
              destination
     * @return hash of source and nonce
     */
    function _hashSourceAndNonce(uint32 _source, uint256 _nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_source, _nonce));
    }

    /**
     * @notice reverts if the attestation, which is comprised of one or more concatenated 65-byte signatures, is invalid.
     *
     * @dev Rules for valid attestation:
     * 1. length of `_attestation` == 65 (signature length) * signatureThreshold
     * 2. addresses recovered from attestation must be in increasing order.
     * For example, if signature A is signed by address 0x1..., and signature B
     * is signed by address 0x2..., attestation must be passed as AB.
     * 3. no duplicate signers
     * 4. all signers must be enabled attesters
     *
     * Based on Christian Lundkvist's Simple Multisig
     * (https://github.com/christianlundkvist/simple-multisig/tree/560c463c8651e0a4da331bd8f245ccd2a48ab63d)
     */
    function _verifyAttestationSignatures(
        bytes memory _message,
        bytes calldata _attestation
    ) internal view {
        require(
            _attestation.length == signatureLength * signatureThreshold,
            "Invalid attestation length"
        );

        // (Attesters cannot be address(0))
        address latestAttesterAddress = address(0);
        // Address recovered from signatures must be in increasing order, to prevent duplicates
        for (uint256 i = 0; i < signatureThreshold; i++) {
            bytes memory _signature = _attestation[i * signatureLength:i *
                signatureLength +
                signatureLength];
            address recoveredAttester = _recoverAttesterSignature(
                _message,
                _signature
            );
            require(
                recoveredAttester > latestAttesterAddress,
                "Signature verification failed: signer is out of order or duplicate"
            );
            require(
                enabledAttesters.contains(recoveredAttester),
                "Signature verification failed: signer is not enabled attester"
            );
            latestAttesterAddress = recoveredAttester;
        }
    }

    /**
     * @notice Checks that signature was signed by attester
     * @param _message unsigned message bytes
     * @param _signature message signature
     * @return address of recovered signer
     **/
    function _recoverAttesterSignature(
        bytes memory _message,
        bytes memory _signature
    ) internal view returns (address) {
        bytes32 _digest = keccak256(_message);
        return (ECDSA.recover(_digest, _signature));
    }
}
