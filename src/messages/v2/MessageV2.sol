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

import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";

/**
 * @title MessageV2 Library
 * @notice Library for formatted v2 messages used by Relayer and Receiver.
 *
 * @dev The message body is dynamically-sized to support custom message body
 * formats. Other fields must be fixed-size to avoid hash collisions.
 * Each other input value has an explicit type to guarantee fixed-size.
 * Padding: uintNN fields are left-padded, and bytesNN fields are right-padded.
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
 * @dev Differences from v1:
 * - Nonce is now bytes32 (vs. uint64)
 * - minFinalityThreshold added
 * - finalityThresholdExecuted added
 **/
library MessageV2 {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // Indices of each field in message
    uint8 private constant VERSION_INDEX = 0;
    uint8 private constant SOURCE_DOMAIN_INDEX = 4;
    uint8 private constant DESTINATION_DOMAIN_INDEX = 8;
    uint8 private constant NONCE_INDEX = 12;
    uint8 private constant SENDER_INDEX = 44;
    uint8 private constant RECIPIENT_INDEX = 76;
    uint8 private constant DESTINATION_CALLER_INDEX = 108;
    uint8 private constant MIN_FINALITY_THRESHOLD_INDEX = 140;
    uint8 private constant FINALITY_THRESHOLD_EXECUTED_INDEX = 144;
    uint8 private constant MESSAGE_BODY_INDEX = 148;

    bytes32 private constant EMPTY_NONCE = bytes32(0);
    uint32 private constant EMPTY_FINALITY_THRESHOLD_EXECUTED = 0;

    /**
     * @notice Returns formatted (packed) message with provided fields
     * @param _version the version of the message format
     * @param _sourceDomain Domain of home chain
     * @param _destinationDomain Domain of destination chain
     * @param _sender Address of sender on source chain as bytes32
     * @param _recipient Address of recipient on destination chain as bytes32
     * @param _destinationCaller Address of caller on destination chain as bytes32
     * @param _minFinalityThreshold the minimum finality at which the message should be attested to
     * @param _messageBody Raw bytes of message body
     * @return Formatted message
     **/
    function _formatMessageForRelay(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _version,
                _sourceDomain,
                _destinationDomain,
                EMPTY_NONCE,
                _sender,
                _recipient,
                _destinationCaller,
                _minFinalityThreshold,
                EMPTY_FINALITY_THRESHOLD_EXECUTED,
                _messageBody
            );
    }

    // @notice Returns _message's version field
    function _getVersion(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(VERSION_INDEX, 4));
    }

    // @notice Returns _message's sourceDomain field
    function _getSourceDomain(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(SOURCE_DOMAIN_INDEX, 4));
    }

    // @notice Returns _message's destinationDomain field
    function _getDestinationDomain(
        bytes29 _message
    ) internal pure returns (uint32) {
        return uint32(_message.indexUint(DESTINATION_DOMAIN_INDEX, 4));
    }

    // @notice Returns _message's nonce field
    function _getNonce(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(NONCE_INDEX, 32);
    }

    // @notice Returns _message's sender field
    function _getSender(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(SENDER_INDEX, 32);
    }

    // @notice Returns _message's recipient field
    function _getRecipient(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(RECIPIENT_INDEX, 32);
    }

    // @notice Returns _message's destinationCaller field
    function _getDestinationCaller(
        bytes29 _message
    ) internal pure returns (bytes32) {
        return _message.index(DESTINATION_CALLER_INDEX, 32);
    }

    // @notice Returns _message's minFinalityThreshold field
    function _getMinFinalityThreshold(
        bytes29 _message
    ) internal pure returns (uint32) {
        return uint32(_message.indexUint(MIN_FINALITY_THRESHOLD_INDEX, 4));
    }

    // @notice Returns _message's finalityThresholdExecuted field
    function _getFinalityThresholdExecuted(
        bytes29 _message
    ) internal pure returns (uint32) {
        return uint32(_message.indexUint(FINALITY_THRESHOLD_EXECUTED_INDEX, 4));
    }

    // @notice Returns _message's messageBody field
    function _getMessageBody(bytes29 _message) internal pure returns (bytes29) {
        return
            _message.slice(
                MESSAGE_BODY_INDEX,
                _message.len() - MESSAGE_BODY_INDEX,
                0
            );
    }

    /**
     * @notice Reverts if message is malformed or too short
     * @param _message The message as bytes29
     */
    function _validateMessageFormat(bytes29 _message) internal pure {
        require(_message.isValid(), "Malformed message");
        require(
            _message.len() >= MESSAGE_BODY_INDEX,
            "Invalid message: too short"
        );
    }
}
