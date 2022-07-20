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

import "@memview-sol/contracts/TypedMemView.sol";

abstract contract Receiver {
    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // ============ Constructor ============
    constructor() {
    }

    // ======== External Functions ========
    /**
     * @notice Receives an incoming message, validating the header and passing 
     * the body to application-specific handler.
     * @param _message The message raw bytes
     */
    function receiveMessage(
        bytes memory _message
    ) external {
        // TODO stub
    }
}
