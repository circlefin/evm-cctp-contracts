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
pragma abicoder v2;

import {IMessageTransmitterV2} from "../interfaces/v2/IMessageTransmitterV2.sol";
import {Attestable} from "../roles/Attestable.sol";
import {Pausable} from "../roles/Pausable.sol";
import {Rescuable} from "../roles/Rescuable.sol";
import {MessageV2} from "../messages/v2/MessageV2.sol";
import {AddressUtils} from "../messages/v2/AddressUtils.sol";

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
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ Libraries ============

    // ============ State Variables ============
    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // Message Format version
    uint32 public immutable version;

    // Maximum size of message body, in bytes.
    // This value is set by owner.
    uint256 public maxMessageBodySize;

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

    function receiveMessage(
        bytes calldata message,
        bytes calldata signature
    ) external override returns (bool success) {}

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
