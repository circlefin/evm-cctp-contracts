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

import "../src/CircleMinter.sol";
import "../lib/forge-std/src/Test.sol";

contract TestUtils is Test {
    function linkTokenPair(
        CircleMinter circleMinter,
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteTokenBytes32
    ) public {
        circleMinter.setLocalTokenEnabledStatus(_localToken, true);

        circleMinter.linkTokenPair(
            address(_localToken),
            _remoteDomain,
            _remoteTokenBytes32
        );

        address _actualLocalToken = circleMinter.getEnabledLocalToken(
            _remoteDomain,
            _remoteTokenBytes32
        );

        assertEq(_actualLocalToken, address(_localToken));
    }
}
