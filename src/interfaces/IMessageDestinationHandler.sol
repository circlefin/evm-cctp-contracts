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
pragma solidity 0.7.6;

/**
 * @title IMessageDestinationHandler
 * @notice Handles messages on destination domain forwarded from
 * an IReceiver
 */
interface IMessageDestinationHandler {
    /**
     * @notice handles an incoming message from a Receiver
     * @param _sourceDomain the source domain of the message
     * @param _sender the sender of the message
     * @param _messageBody The message raw bytes
     * @return success bool, true if successful
     */
    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 _sender,
        bytes memory _messageBody
    ) external returns (bool);
}
