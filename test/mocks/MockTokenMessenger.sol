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

import "../../src/interfaces/IMessageHandler.sol";

contract MockTokenMessenger is IMessageHandler {
    // ============ Constructor ============
    constructor() {}

    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 _sender,
        bytes memory _messageBody
    ) external override returns (bool) {
        // revert if _messageBody is 'revert', otherwise do nothing
        require(
            keccak256(_messageBody) != keccak256(bytes("revert")),
            "mock revert"
        );

        if (keccak256(_messageBody) == keccak256(bytes("return false"))) {
            return false;
        }

        return true;
    }
}
