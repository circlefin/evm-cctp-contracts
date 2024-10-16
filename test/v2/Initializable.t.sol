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

import {Initializable} from "../../src/v2/Initializable.sol";
import {MockInitializableImplementation} from "../mocks/MockInitializableImplementation.sol";
import {Test} from "forge-std/Test.sol";

contract InitializableTest is Test {
    MockInitializableImplementation private impl;

    event Initialized(uint64 version);

    function setUp() public {
        impl = new MockInitializableImplementation();
    }

    function test_canBeInitializedToNextIncrementedVersionFromZero() public {
        assertEq(uint256(impl.initializedVersion()), 0);

        // Upgrade 0 -> 1
        vm.expectEmit(true, true, true, true);
        emit Initialized(1);
        impl.initialize(address(10), 1);
        assertEq(uint256(impl.initializedVersion()), 1);
    }

    function test_canBeReinitializedToNextIncrementedVersionFromNonZero()
        public
    {
        impl.initialize(address(10), 1);
        assertEq(uint256(impl.initializedVersion()), 1);

        // Upgrade 1 -> 2
        vm.expectEmit(true, true, true, true);
        emit Initialized(2);
        impl.initializeV2();
        assertEq(uint256(impl.initializedVersion()), 2);
    }

    function test_canJumpToLaterVersionFromZero() public {
        assertEq(uint256(impl.initializedVersion()), 0);

        // Upgrade 0 -> 2
        vm.expectEmit(true, true, true, true);
        emit Initialized(2);
        impl.initializeV2();
        assertEq(uint256(impl.initializedVersion()), 2);
    }

    function test_canJumpToLaterVersionFromNonZero() public {
        impl.initialize(address(10), 1);
        assertEq(uint256(impl.initializedVersion()), 1);

        // Upgrade 1 -> 3
        vm.expectEmit(true, true, true, true);
        emit Initialized(3);
        impl.initializeV3();
        assertEq(uint256(impl.initializedVersion()), 3);
    }

    function test_revertsIfInitializerIsCalledTwice() public {
        impl.initialize(address(10), 1);

        vm.expectRevert("Initializable: invalid initialization");
        impl.initialize(address(10), 1);
    }

    function test_revertsIfReinitializerIsCalledTwice() public {
        impl.initializeV2();

        vm.expectRevert("Initializable: invalid initialization");
        impl.initializeV2();
    }

    function test_revertsIfInitializersAreDisabled() public {
        impl.disableInitializers();

        vm.expectRevert("Initializable: invalid initialization");
        impl.initialize(address(10), 1);
    }

    function test_revertsIfDowngraded() public {
        impl.initializeV3();
        assertEq(uint256(impl.initializedVersion()), 3);

        // Downgrade 3 -> 2
        vm.expectRevert("Initializable: invalid initialization");
        impl.initializeV2();

        assertEq(uint256(impl.initializedVersion()), 3);
    }
}
