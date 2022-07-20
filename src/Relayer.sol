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

abstract contract Relayer {
    // ============ Events ============
    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(
        // TODO maybe add messageHash
        bytes message
    );

    // ============ Constructor ============
    constructor() {
    }

    // ============ Public Functions  ============
    /**
     * @notice Send the message to the destination domain and recipient
     * @dev Increment nonce, format the message, and emit `MessageSent` event with message information.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as bytes32
     * @param _messageBody Raw bytes content of message
     */
    function sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes memory _messageBody
    ) public
    // TODO whenNotPaused (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5fbf494511fd522b931f7f92e2df87d671ea8b0b/contracts/security/Pausable.sol)
    {
        // TODO stub
        // Emit MessageSent event with message information
        emit MessageSent(
            bytes('foo')
        );
    }
}
