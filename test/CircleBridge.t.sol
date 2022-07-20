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

import "forge-std/Test.sol";
import "../src/Relayer.sol";
import "../src/Receiver.sol";
import "../src/CircleBridge.sol";

contract CircleBridgeTest is Test {
    // ============ Libraries ============
    CircleBridge circleBridge;
    uint32 _destinationDomain = 1;

    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(
        bytes message
    );

    function setUp() public {
        circleBridge = new CircleBridge();
    }

    function testRelay() public {
        bytes32 _recipientAddress = bytes32(uint256(uint160(vm.addr(1505))));

        // assert that a MessageSent event was logged with expected message bytes
        vm.expectEmit(true, true, true, true);
        emit MessageSent(bytes("foo"));
        circleBridge.sendMessage(_destinationDomain, _recipientAddress, bytes("bar"));
    }
}
