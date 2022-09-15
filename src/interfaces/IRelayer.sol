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

/**
 * @title IRelayer
 * @notice Sends messages from source domain to destination domain
 */
interface IRelayer {
    /**
     * @notice Sends an outgoing message from the source domain.
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of message recipient on destination domain as bytes32
     * @param _messageBody Raw bytes content of message
     * @return _nonce unique nonce reserved by message
     */
    function sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes memory _messageBody
    ) external returns (uint64 _nonce);

    /**
     * @notice Sends an outgoing message from the source domain, with a specified caller on the
     * destination domain.
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * WARNING: if the `_destinationCaller` does not represent a valid address as bytes32, then it will not be possible
     * to broadcast the message on the destination domain. This is an advanced feature, and the standard
     * sendMessage() should be preferred for use cases where a specific destination caller is not required.
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of message recipient on destination domain as bytes32
     * @param _destinationCaller caller on the destination domain, as bytes32
     * @param _messageBody Raw bytes content of message
     * @return _nonce unique nonce reserved by message
     */
    function sendMessageWithCaller(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        bytes memory _messageBody
    ) external returns (uint64 _nonce);
}
