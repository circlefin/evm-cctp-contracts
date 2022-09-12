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

import "../../src/roles/Attestable.sol";
import "../../lib/forge-std/src/Test.sol";

contract AttestableTest is Test {
    /**
     * @dev Emitted when attester manager address is updated
     * @param previousAttesterManager representing the address of the previous attester manager
     * @param newAttesterManager representing the address of the new attester manager
     */
    event AttesterManagerUpdated(
        address previousAttesterManager,
        address newAttesterManager
    );

    address initialAttester = vm.addr(1505);
    Attestable attestable;

    function setUp() public {
        vm.prank(initialAttester);
        attestable = new Attestable();
    }

    function testConstructor_setsAttesterManager() public {
        vm.prank(initialAttester);
        Attestable _attester = new Attestable();
        assertEq(_attester.attesterManager(), initialAttester);
    }

    function testUpdateAttesterManager_revertsWhenCalledByWrongAttesterManager()
        public
    {
        assertEq(attestable.attesterManager(), initialAttester);
        address _newAttesterManager = vm.addr(1506);

        vm.expectRevert("Attestable: caller is not the attester manager");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), initialAttester);
    }

    function testUpdateAttesterManager_revertsWhenGivenZeroAddress() public {
        assertEq(attestable.attesterManager(), initialAttester);
        address _newAttesterManager = address(0);

        vm.prank(initialAttester);
        vm.expectRevert("Attestable: new attester manager is the zero address");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), initialAttester);
    }

    function testUpdateAttesterManager_succeeds() public {
        assertEq(attestable.attesterManager(), initialAttester);
        address _newAttesterManager = vm.addr(1506);

        vm.expectEmit(true, true, true, true);
        emit AttesterManagerUpdated(_newAttesterManager, _newAttesterManager);
        vm.prank(initialAttester);
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), _newAttesterManager);
    }
}
