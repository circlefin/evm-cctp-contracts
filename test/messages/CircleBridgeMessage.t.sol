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
import "forge-std/Test.sol";
import "../../src/messages/CircleBridgeMessage.sol";
import "../../src/messages/Message.sol";

contract CircleBridgeMessageTest is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using CircleBridgeMessage for bytes29;

    function testFormatCircleBridgeMessage(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount
    ) public {
        // Format message body
        bytes memory _messageBody = CircleBridgeMessage.formatDepositForBurn(
            _burnToken,
            _mintRecipient,
            _amount
        );

        bytes29 _m = _messageBody.ref(0);
        assertEq(_m.getMintRecipient(), _mintRecipient);
        assertEq(_m.getBurnToken(), _burnToken);
        assertEq(_m.getAmount(), _amount);
        _m.assertType(uint40(CircleBridgeMessage.Types.DepositForBurn));
    }
}
