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

import {Create2Factory} from "../../src/v2/Create2Factory.sol";
import {MockInitializableImplementation} from "../mocks/MockInitializableImplementation.sol";
import {UpgradeableProxy} from "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";
import {Test} from "forge-std/Test.sol";

contract Create2FactoryTest is Test {
    Create2Factory private create2Factory;
    MockInitializableImplementation private impl;

    event Upgraded(address indexed implementation);

    function setUp() public {
        create2Factory = new Create2Factory();
        impl = new MockInitializableImplementation();
    }

    function test_SetUpState() public {
        // Check owners
        assertEq(create2Factory.owner(), address(this));
    }

    function testDeploy(address addr, uint256 num, bytes32 salt) public {
        // Construct initializer
        bytes memory initializer = abi.encodeWithSelector(
            MockInitializableImplementation.initialize.selector,
            addr,
            num
        );
        // Construct bytecode
        bytes memory bytecode = abi.encodePacked(
            type(UpgradeableProxy).creationCode,
            abi.encode(address(impl), initializer)
        );
        // Deploy proxy
        address expectedAddr = create2Factory.computeAddress(
            salt,
            keccak256(bytecode)
        );
        address proxyAddr = create2Factory.deploy(0, salt, bytecode);

        // Verify deterministic
        assertEq(proxyAddr, expectedAddr);
        // Check initialized vars
        assertEq(MockInitializableImplementation(proxyAddr).addr(), addr);
        assertEq(MockInitializableImplementation(proxyAddr).num(), num);
    }

    function testDeployAndMultiCall(
        address addr,
        uint256 num,
        uint256 amount,
        bytes32 salt
    ) public {
        // Construct initializers
        bytes memory initializer1 = abi.encodeWithSelector(
            MockInitializableImplementation.initialize.selector,
            addr,
            num
        );
        bytes memory initializer2 = abi.encodeWithSelector(
            MockInitializableImplementation.initializeV2.selector
        );
        bytes[] memory data = new bytes[](2);
        data[0] = initializer1;
        data[1] = initializer2;
        // Construct bytecode
        bytes memory bytecode = abi.encodePacked(
            type(UpgradeableProxy).creationCode,
            abi.encode(address(impl), "")
        );
        // Deploy proxy
        address expectedAddr = create2Factory.computeAddress(
            salt,
            keccak256(bytecode)
        );
        vm.deal(address(this), amount);

        // Expect calls
        vm.expectCall(expectedAddr, initializer1);
        vm.expectCall(expectedAddr, initializer2);

        address proxyAddr = create2Factory.deployAndMultiCall{value: amount}(
            amount,
            salt,
            bytecode,
            data
        );

        // Verify deterministic
        assertEq(proxyAddr, expectedAddr);
        // Check initialized vars
        assertEq(MockInitializableImplementation(proxyAddr).addr(), addr);
        assertEq(MockInitializableImplementation(proxyAddr).num(), num);
        // Verify balance
        assertEq(proxyAddr.balance, amount);
    }
}
