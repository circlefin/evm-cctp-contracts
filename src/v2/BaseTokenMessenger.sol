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

import {Ownable2Step} from "../roles/Ownable2Step.sol";
import {ITokenMinter} from "../interfaces/ITokenMinter.sol";
import {Rescuable} from "../roles/Rescuable.sol";

/**
 * @title BaseTokenMessenger
 * @notice Base administrative functionality for TokenMessenger implementations,
 * including managing remote token messengers and the local token minter.
 */
abstract contract BaseTokenMessenger is Rescuable {
    // ============ Events ============
    /**
     * @notice Emitted when a remote TokenMessenger is added
     * @param domain remote domain
     * @param tokenMessenger TokenMessenger on remote domain
     */
    event RemoteTokenMessengerAdded(uint32 domain, bytes32 tokenMessenger);

    /**
     * @notice Emitted when a remote TokenMessenger is removed
     * @param domain remote domain
     * @param tokenMessenger TokenMessenger on remote domain
     */
    event RemoteTokenMessengerRemoved(uint32 domain, bytes32 tokenMessenger);

    /**
     * @notice Emitted when the local minter is added
     * @param localMinter address of local minter
     * @notice Emitted when the local minter is added
     */
    event LocalMinterAdded(address localMinter);

    /**
     * @notice Emitted when the local minter is removed
     * @param localMinter address of local minter
     * @notice Emitted when the local minter is removed
     */
    event LocalMinterRemoved(address localMinter);

    // ============ State Variables ============
    // Local Message Transmitter responsible for sending and receiving messages to/from remote domains
    address public immutable localMessageTransmitter;

    // Version of message body format
    uint32 public immutable messageBodyVersion;

    // Minter responsible for minting and burning tokens on the local domain
    ITokenMinter public localMinter;

    // Valid TokenMessengers on remote domains
    mapping(uint32 => bytes32) public remoteTokenMessengers;

    // ============ Modifiers ============
    /**
     * @notice Only accept messages from a registered TokenMessenger contract on given remote domain
     * @param domain The remote domain
     * @param tokenMessenger The address of the TokenMessenger contract for the given remote domain
     */
    modifier onlyRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger) {
        require(
            _isRemoteTokenMessenger(domain, tokenMessenger),
            "Remote TokenMessenger unsupported"
        );
        _;
    }

    /**
     * @notice Only accept messages from the registered message transmitter on local domain
     */
    modifier onlyLocalMessageTransmitter() {
        // Caller must be the registered message transmitter for this domain
        require(_isLocalMessageTransmitter(), "Invalid message transmitter");
        _;
    }

    // ============ Constructor ============
    /**
     * @param _messageTransmitter Message transmitter address
     * @param _messageBodyVersion Message body version
     */
    constructor(address _messageTransmitter, uint32 _messageBodyVersion) {
        require(
            _messageTransmitter != address(0),
            "MessageTransmitter not set"
        );
        localMessageTransmitter = _messageTransmitter;
        messageBodyVersion = _messageBodyVersion;
    }

    // ============ External Functions  ============
    /**
     * @notice Add the TokenMessenger for a remote domain.
     * @dev Reverts if there is already a TokenMessenger set for domain.
     * @param domain Domain of remote TokenMessenger.
     * @param tokenMessenger Address of remote TokenMessenger as bytes32.
     */
    function addRemoteTokenMessenger(
        uint32 domain,
        bytes32 tokenMessenger
    ) external onlyOwner {
        require(tokenMessenger != bytes32(0), "bytes32(0) not allowed");

        require(
            remoteTokenMessengers[domain] == bytes32(0),
            "TokenMessenger already set"
        );

        remoteTokenMessengers[domain] = tokenMessenger;
        emit RemoteTokenMessengerAdded(domain, tokenMessenger);
    }

    /**
     * @notice Remove the TokenMessenger for a remote domain.
     * @dev Reverts if there is no TokenMessenger set for `domain`.
     * @param domain Domain of remote TokenMessenger
     */
    function removeRemoteTokenMessenger(uint32 domain) external onlyOwner {
        // No TokenMessenger set for given remote domain.
        require(
            remoteTokenMessengers[domain] != bytes32(0),
            "No TokenMessenger set"
        );

        bytes32 _removedTokenMessenger = remoteTokenMessengers[domain];
        delete remoteTokenMessengers[domain];
        emit RemoteTokenMessengerRemoved(domain, _removedTokenMessenger);
    }

    /**
     * @notice Add minter for the local domain.
     * @dev Reverts if a minter is already set for the local domain.
     * @param newLocalMinter The address of the minter on the local domain.
     */
    function addLocalMinter(address newLocalMinter) external onlyOwner {
        require(newLocalMinter != address(0), "Zero address not allowed");

        require(
            address(localMinter) == address(0),
            "Local minter is already set."
        );

        localMinter = ITokenMinter(newLocalMinter);

        emit LocalMinterAdded(newLocalMinter);
    }

    /**
     * @notice Remove the minter for the local domain.
     * @dev Reverts if the minter of the local domain is not set.
     */
    function removeLocalMinter() external onlyOwner {
        address _localMinterAddress = address(localMinter);
        require(_localMinterAddress != address(0), "No local minter is set.");

        delete localMinter;
        emit LocalMinterRemoved(_localMinterAddress);
    }

    // ============ Internal Utils ============
    /**
     * @notice return the remote TokenMessenger for the given `_domain` if one exists, else revert.
     * @param _domain The domain for which to get the remote TokenMessenger
     * @return _tokenMessenger The address of the TokenMessenger on `_domain` as bytes32
     */
    function _getRemoteTokenMessenger(
        uint32 _domain
    ) internal view returns (bytes32) {
        bytes32 _tokenMessenger = remoteTokenMessengers[_domain];
        require(_tokenMessenger != bytes32(0), "No TokenMessenger for domain");
        return _tokenMessenger;
    }

    /**
     * @notice return the local minter address if it is set, else revert.
     * @return local minter as ITokenMinter.
     */
    function _getLocalMinter() internal view returns (ITokenMinter) {
        require(address(localMinter) != address(0), "Local minter is not set");
        return localMinter;
    }

    /**
     * @notice Return true if the given remote domain and TokenMessenger is registered
     * on this TokenMessenger.
     * @param _domain The remote domain of the message.
     * @param _tokenMessenger The address of the TokenMessenger on remote domain.
     * @return true if a remote TokenMessenger is registered for `_domain` and `_tokenMessenger`,
     * on this TokenMessenger.
     */
    function _isRemoteTokenMessenger(
        uint32 _domain,
        bytes32 _tokenMessenger
    ) internal view returns (bool) {
        return
            _tokenMessenger != bytes32(0) &&
            remoteTokenMessengers[_domain] == _tokenMessenger;
    }

    /**
     * @notice Returns true if the message sender is the local registered MessageTransmitter
     * @return true if message sender is the registered local message transmitter
     */
    function _isLocalMessageTransmitter() internal view returns (bool) {
        return
            address(localMessageTransmitter) != address(0) &&
            msg.sender == address(localMessageTransmitter);
    }
}
