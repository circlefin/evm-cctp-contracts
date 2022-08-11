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

import "../../src/interfaces/IRelayer.sol";

/**
 * @title MockRelayer
 * @notice Mock Relayer that returns false on sendMessage() requests.
 */
contract MockRelayer is IRelayer {
    // ============ Constructor ============
    constructor() {}

    // ============ Public Functions  ============
    /**
     * @notice This method is mocked to always return false for testing.
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of message recipient on destination chain as bytes32
     * @param _messageBody Raw bytes content of message
     * @return success bool, true if successful
     */
    function sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes memory _messageBody
    ) external override returns (bool success) {
        return false;
    }
}
