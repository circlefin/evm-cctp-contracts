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

import "../../src/interfaces/IReceiver.sol";

contract MockRepeatCaller {
    // ============ Constructor ============
    constructor() {}

    /**
     * @notice attempts to receive a message twice in the same transaction
     * @param _message The message raw bytes
     * @param _signature The message signature
     */
    function callReceiveMessageTwice(
        address _receiver,
        bytes memory _message,
        bytes memory _signature
    ) external {
        IReceiver(_receiver).receiveMessage(_message, _signature);
        IReceiver(_receiver).receiveMessage(_message, _signature);
    }
}
