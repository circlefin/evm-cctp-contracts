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
import "../src/Message.sol";

contract MessageTest is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;

    // Number of bytes in formatted message before `_messageBody` field
    uint256 internal constant MESSAGE_BODY_INDEX = 112;

    function testFormatMessage(uint32 _version, uint32 _sourceDomain, uint32 _destinationDomain, uint32 _nonce, bytes32 _recipient, bytes memory _messageBody) public {
        bytes memory message = Message.formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _recipient,
            _messageBody
        );

        bytes29 _m = message.ref(0);
        assertEq(uint256(_m.version()), uint256(_version));
        assertEq(uint256(_m.sourceDomain()), uint256(_sourceDomain));
        assertEq(uint256(_m.destinationDomain()), uint256(_destinationDomain));
        assertEq(uint256(_m.nonce()), uint256(_nonce));
        assertEq(_m.recipient(), _recipient);
        assertEq(_m.messageBody().clone(), _messageBody);
    }

    function testFormatMessageFixture() public {
        uint32 _version = 1;
        uint32 _sourceDomain = 1111;
        uint32 _destinationDomain = 1234;
        uint32 _nonce = 4294967295; // uint32 max value

        bytes32 _recipient = bytes32(uint256(uint160(vm.addr(1505))));
        bytes memory _messageBody = bytes("test message");

        bytes memory message = Message.formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _recipient,
            _messageBody
        );

        bytes29 _m = message.ref(0);
        assertEq(uint256(_m.version()), uint256(_version));
        assertEq(uint256(_m.sourceDomain()), uint256(_sourceDomain));
        assertEq(uint256(_m.destinationDomain()), uint256(_destinationDomain));
        assertEq(uint256(_m.nonce()), uint256(_nonce));
        assertEq(_m.recipient(), _recipient);
        assertEq(_m.messageBody().clone(), _messageBody);
    }
}
