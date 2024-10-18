/*
 * Copyright 2024 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;
pragma abicoder v2;

import {MockDenylistable} from "../../mocks/v2/MockDenylistable.sol";
import {Test} from "forge-std/Test.sol";

contract DenylistableTest is Test {
    // Test events
    event DenylisterChanged(
        address indexed oldDenylister,
        address indexed newDenylister
    );
    event Denylisted(address indexed account);
    event UnDenylisted(address indexed account);

    // Test constants
    address owner = address(10);
    address denylister = address(20);

    MockDenylistable denylistable;

    function setUp() public {
        vm.startPrank(owner);
        denylistable = new MockDenylistable();
        denylistable.updateDenylister(denylister);

        assertEq(denylistable.owner(), owner);
        assertEq(denylistable.denylister(), denylister);

        vm.stopPrank();
    }

    // Tests

    function testUpdateDenylister_revertsIfNotCalledByOwner(
        address _notOwner,
        address _otherAddress
    ) public {
        vm.assume(_notOwner != owner);
        vm.assume(_otherAddress != address(0));

        vm.prank(_notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        denylistable.updateDenylister(_otherAddress);
    }

    function testUpdateDenylister_revertsIfDenylisterIsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Denylistable: new denylister is the zero address");
        denylistable.updateDenylister(address(0));
    }

    function testUpdateDenylister_succeeds(address _newDenylister) public {
        vm.assume(_newDenylister != address(0));

        vm.expectEmit(true, true, true, true);
        emit DenylisterChanged(denylister, _newDenylister);

        vm.prank(owner);
        denylistable.updateDenylister(_newDenylister);
        assertEq(denylistable.denylister(), _newDenylister);
    }

    function testDenylist_revertsIfNotCalledByDenylister(
        address _randomCaller,
        address _deniedAddress
    ) public {
        vm.assume(_randomCaller != denylister);

        vm.prank(_randomCaller);
        vm.expectRevert("Denylistable: caller is not denylister");
        denylistable.denylist(_deniedAddress);
    }

    function testDenylist_succeeds(address _deniedAddress) public {
        vm.expectEmit(true, true, true, true);
        emit Denylisted(_deniedAddress);

        vm.prank(denylister);
        denylistable.denylist(_deniedAddress);
        assertTrue(denylistable.isDenylisted(_deniedAddress));
    }

    function testUndenylist_revertsIfNotCalledByDenylister(
        address _randomCaller,
        address _addressToRemove
    ) public {
        vm.assume(_randomCaller != denylister);

        vm.prank(_randomCaller);
        vm.expectRevert("Denylistable: caller is not denylister");
        denylistable.unDenylist(_addressToRemove);
    }

    function testUndenylist_succeeds(address _addressToRemove) public {
        // First add to denylist
        vm.prank(denylister);
        denylistable.denylist(_addressToRemove);

        // Verify
        assertTrue(denylistable.isDenylisted(_addressToRemove));

        vm.expectEmit(true, true, true, true);
        emit UnDenylisted(_addressToRemove);

        vm.prank(denylister);
        denylistable.unDenylist(_addressToRemove);
        assertFalse(denylistable.isDenylisted(_addressToRemove));
    }

    function testDenylister_returnsTheCurrentDenylister(
        address _newDenylister
    ) public {
        vm.assume(_newDenylister != denylister);
        vm.assume(_newDenylister != address(0));

        // Sanity check
        assertEq(denylistable.denylister(), denylister);

        // Change to new address
        vm.prank(owner);
        denylistable.updateDenylister(_newDenylister);
        assertEq(denylistable.denylister(), _newDenylister);
    }

    function testDenylisted_returnsIfAnAddressIsOnTheDenylist(
        address _deniedAddress
    ) public {
        // Sanity check
        assertFalse(denylistable.isDenylisted(_deniedAddress));

        // Add to deny list
        vm.prank(denylister);
        denylistable.denylist(_deniedAddress);
        assertTrue(denylistable.isDenylisted(_deniedAddress));

        // Remove again
        vm.prank(denylister);
        denylistable.unDenylist(_deniedAddress);
        assertFalse(denylistable.isDenylisted(_deniedAddress));
    }

    function testNotDenylistedCallers_revertsIfMessageSenderIsDenylisted(
        address _messageSender,
        address _txOrigin
    ) public {
        vm.assume(_messageSender != _txOrigin);

        // Sanity checks
        assertFalse(denylistable.isDenylisted(_messageSender));
        assertFalse(denylistable.isDenylisted(_txOrigin));

        // Add messageSender to deny list
        vm.prank(denylister);
        denylistable.denylist(_messageSender);

        // Now, mock with modifier should fail
        vm.prank(_messageSender, _txOrigin);
        vm.expectRevert("Denylistable: account is on denylist");
        denylistable.sensitiveFunction();
    }

    function testNotDenylistedCallers_revertsIfTxOriginIsDenylisted(
        address _messageSender,
        address _txOrigin
    ) public {
        vm.assume(_messageSender != _txOrigin);

        // Sanity checks
        assertFalse(denylistable.isDenylisted(_messageSender));
        assertFalse(denylistable.isDenylisted(_txOrigin));

        // Add messageSender to deny list
        vm.prank(denylister);
        denylistable.denylist(_txOrigin);

        // Now, mock with modifier should fail
        vm.prank(_messageSender, _txOrigin);
        vm.expectRevert("Denylistable: account is on denylist");
        denylistable.sensitiveFunction();
    }

    function testNotDenylistedCallers_revertsIfBothMessageSenderAndTxOriginAreDenylistedAndDistinct(
        address _messageSender,
        address _txOrigin
    ) public {
        vm.assume(_messageSender != _txOrigin);

        // Sanity checks
        assertFalse(denylistable.isDenylisted(_messageSender));
        assertFalse(denylistable.isDenylisted(_txOrigin));

        // Add messageSender to deny list
        vm.startPrank(denylister);
        denylistable.denylist(_messageSender);
        denylistable.denylist(_txOrigin);
        vm.stopPrank();

        // Now, mock with modifier should fail
        vm.prank(_messageSender, _txOrigin);
        vm.expectRevert("Denylistable: account is on denylist");
        denylistable.sensitiveFunction();
    }

    function testNotDenylistedCallers_revertsForSameCallers(
        address _caller
    ) public {
        // Sanity check
        assertFalse(denylistable.isDenylisted(_caller));

        // Add messageSender to deny list
        vm.prank(denylister);
        denylistable.denylist(_caller);

        // Now, mock with modifier should fail
        vm.prank(_caller, _caller);
        vm.expectRevert("Denylistable: account is on denylist");
        denylistable.sensitiveFunction();
    }

    function testNotDenylistedCallers_succeedsForDistinctCallers(
        address _messageSender,
        address _txOrigin
    ) public {
        // Sanity checks
        assertFalse(denylistable.isDenylisted(_messageSender));
        assertFalse(denylistable.isDenylisted(_txOrigin));

        // Call should succeed
        vm.prank(_messageSender, _txOrigin);
        assertTrue(denylistable.sensitiveFunction());
    }

    function testNotDenylistedCallers_succeedsForTheSameCaller(
        address _caller
    ) public {
        // Sanity check
        assertFalse(denylistable.isDenylisted(_caller));

        // Call should succeed
        vm.prank(_caller, _caller);
        assertTrue(denylistable.sensitiveFunction());
    }
}
