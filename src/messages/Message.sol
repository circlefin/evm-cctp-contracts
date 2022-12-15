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

/**
 * @title Message Library
 * @notice Library for formatted messages used by Relayer and Receiver.
 *
 * @dev The message body is dynamically-sized to support custom message body
 * formats. Other fields must be fixed-size to avoid hash collisions.
 * Each other input value has an explicit type to guarantee fixed-size.
 * Padding: uintNN fields are left-padded, and bytesNN fields are right-padded.
 *
 * Field                 Bytes      Type       Index
 * version               4          uint32     0
 * sourceDomain          4          uint32     4
 * destinationDomain     4          uint32     8
 * nonce                 8          uint64     12
 * sender                32         bytes32    20
 * recipient             32         bytes32    52
 * destinationCaller     32         bytes32    84
 * messageBody           dynamic    bytes      116
 *
 **/
library Message {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // Indices of each field in message
    uint8 private constant VERSION_INDEX = 0;
    uint8 private constant SOURCE_DOMAIN_INDEX = 4;
    uint8 private constant DESTINATION_DOMAIN_INDEX = 8;
    uint8 private constant NONCE_INDEX = 12;
    uint8 private constant SENDER_INDEX = 20;
    uint8 private constant RECIPIENT_INDEX = 52;
    uint8 private constant DESTINATION_CALLER_INDEX = 84;
    uint8 private constant MESSAGE_BODY_INDEX = 116;

    /**
     * @notice Returns formatted (packed) message with provided fields
     * @param _msgVersion the version of the message format
     * @param _msgSourceDomain Domain of home chain
     * @param _msgDestinationDomain Domain of destination chain
     * @param _msgNonce Destination-specific nonce
     * @param _msgSender Address of sender on source chain as bytes32
     * @param _msgRecipient Address of recipient on destination chain as bytes32
     * @param _msgDestinationCaller Address of caller on destination chain as bytes32
     * @param _msgRawBody Raw bytes of message body
     * @return Formatted message
     **/
    function _formatMessage(
        uint32 _msgVersion,
        uint32 _msgSourceDomain,
        uint32 _msgDestinationDomain,
        uint64 _msgNonce,
        bytes32 _msgSender,
        bytes32 _msgRecipient,
        bytes32 _msgDestinationCaller,
        bytes memory _msgRawBody
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _msgVersion,
                _msgSourceDomain,
                _msgDestinationDomain,
                _msgNonce,
                _msgSender,
                _msgRecipient,
                _msgDestinationCaller,
                _msgRawBody
            );
    }

    // @notice Returns _message's version field
    function _version(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(VERSION_INDEX, 4));
    }

    // @notice Returns _message's sourceDomain field
    function _sourceDomain(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(SOURCE_DOMAIN_INDEX, 4));
    }

    // @notice Returns _message's destinationDomain field
    function _destinationDomain(bytes29 _message)
        internal
        pure
        returns (uint32)
    {
        return uint32(_message.indexUint(DESTINATION_DOMAIN_INDEX, 4));
    }

    // @notice Returns _message's nonce field
    function _nonce(bytes29 _message) internal pure returns (uint64) {
        return uint64(_message.indexUint(NONCE_INDEX, 8));
    }

    // @notice Returns _message's sender field
    function _sender(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(SENDER_INDEX, 32);
    }

    // @notice Returns _message's recipient field
    function _recipient(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(RECIPIENT_INDEX, 32);
    }

    // @notice Returns _message's destinationCaller field
    function _destinationCaller(bytes29 _message)
        internal
        pure
        returns (bytes32)
    {
        return _message.index(DESTINATION_CALLER_INDEX, 32);
    }

    // @notice Returns _message's messageBody field
    function _messageBody(bytes29 _message) internal pure returns (bytes29) {
        return
            _message.slice(
                MESSAGE_BODY_INDEX,
                _message.len() - MESSAGE_BODY_INDEX,
                0
            );
    }

    /**
     * @notice converts address to bytes32 (alignment preserving cast.)
     * @param addr the address to convert to bytes32
     */
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice converts bytes32 to address (alignment preserving cast.)
     * @dev Warning: it is possible to have different input values _buf map to the same address.
     * For use cases where this is not acceptable, validate that the first 12 bytes of _buf are zero-padding.
     * @param _buf the bytes32 to convert to address
     */
    function bytes32ToAddress(bytes32 _buf) public pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

    /**
     * @notice Reverts if message is malformed or incorrect length
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
