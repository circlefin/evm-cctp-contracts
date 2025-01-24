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

import {AttestableV2} from "../roles/v2/AttestableV2.sol";
import {Pausable} from "../roles/Pausable.sol";
import {Rescuable} from "../roles/Rescuable.sol";
import {Initializable} from "../proxy/Initializable.sol";

/**
 * @title BaseMessageTransmitter
 * @notice A base type containing administrative and configuration functionality for message transmitters.
 */
contract BaseMessageTransmitter is
    Initializable,
    Pausable,
    Rescuable,
    AttestableV2
{
    // ============ Events ============
    /**
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ Constants ============
    // A constant value indicating that a nonce has been used
    uint256 public constant NONCE_USED = 1;

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
    constructor(uint32 _localDomain, uint32 _version) AttestableV2() {
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
        _setMaxMessageBodySize(newMaxMessageBodySize);
    }

    /**
     * @notice Returns the current initialized version
     */
    function initializedVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    // ============ Internal Utils ============
    /**
     * @notice Sets the max message body size
     * @param _newMaxMessageBodySize new max message body size, in bytes
     */
    function _setMaxMessageBodySize(uint256 _newMaxMessageBodySize) internal {
        maxMessageBodySize = _newMaxMessageBodySize;
        emit MaxMessageBodySizeUpdated(maxMessageBodySize);
    }
}
