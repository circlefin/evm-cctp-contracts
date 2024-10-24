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
import {Initializable} from "../proxy/Initializable.sol";

/**
 * @title BaseMessageTransmitter
 * @notice Base MessageTransmitter implementation, focused on administrative actions.
 */
contract BaseMessageTransmitter is
    Initializable,
    Pausable,
    Rescuable,
    Attestable
{
    // ============ Events ============
    /**
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ State Variables ============
    // Domain of chain on which the contract is deployed
    uint32 public immutable localDomain;

    // Message Format version
    uint32 public immutable version;

    // Maximum size of message body, in bytes.
    // This value is set by owner.
    uint256 public maxMessageBodySize;

    // Maps a bytes32 nonce -> uint256 (0 if unused, 1 if used)
    mapping(bytes32 => uint256) public usedNonces;

    // ============ Constructor ============
    /**
     * @param _localDomain Domain of chain on which the contract is deployed
     * @param _version Message Format version
     */
    constructor(uint32 _localDomain, uint32 _version) Attestable(msg.sender) {
        localDomain = _localDomain;
        version = _version;
    }

    // ============ External Functions  ============
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

    /**
     * @dev Returns the current initialized version
     */
    function initializedVersion() public view returns (uint64) {
        return _getInitializedVersion();
    }
}
