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

import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MockInitializableImplementation} from "../mocks/MockInitializableImplementation.sol";
import {MockProxyImplementation, MockAlternateProxyImplementation} from "../mocks/v2/MockProxyImplementation.sol";
import {MockPayableProxyImplementation} from "../mocks/v2/MockPayableProxyImplementation.sol";
import {Test} from "forge-std/Test.sol";

contract AdminUpgradableProxyTest is Test {
    // Events

    event AdminChanged(address previousAdmin, address newAdmin);
    event Upgraded(address indexed implementation);

    // Constants

    address proxyAdmin = address(1);

    AdminUpgradableProxy proxy;

    MockProxyImplementation impl;
    MockAlternateProxyImplementation alternateImpl;
    MockInitializableImplementation initializableImpl;
    MockPayableProxyImplementation payableImpl;

    function setUp() public {
        impl = new MockProxyImplementation();
        alternateImpl = new MockAlternateProxyImplementation();
        initializableImpl = new MockInitializableImplementation();
        payableImpl = new MockPayableProxyImplementation();

        proxy = new AdminUpgradableProxy(address(impl), proxyAdmin, bytes(""));
    }

    // Tests

    function testConstructor_setsTheImplementation() public view {
        assertEq(proxy.implementation(), address(impl));
    }

    function testConstructor_setsTheProxyAdmin() public view {
        assertEq(proxy.admin(), proxyAdmin);
    }

    function testConstructor_revertsIfInitializationCallFails() public {
        bytes4 badSelector = bytes4(keccak256("notafunction()"));

        vm.expectRevert("Address: low-level delegate call failed");
        new AdminUpgradableProxy(
            address(impl),
            proxyAdmin,
            abi.encodeWithSelector(badSelector)
        );
    }

    function testConstructor_initializesWithExtraData(
        address _randomAddress,
        uint256 _randomNumber
    ) public {
        bytes memory _initializationData = abi.encodeWithSelector(
            MockInitializableImplementation.initialize.selector,
            _randomAddress,
            _randomNumber
        );
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(initializableImpl),
            proxyAdmin,
            _initializationData
        );
        MockInitializableImplementation _proxyAsImpl = MockInitializableImplementation(
                address(_proxy)
            );

        assertEq(_proxyAsImpl.addr(), _randomAddress);
        assertEq(_proxyAsImpl.num(), _randomNumber);
    }

    function testImplementation_returnsTheImplementationContractAddress(
        address _randomCaller
    ) public {
        vm.prank(_randomCaller);
        assertEq(proxy.implementation(), address(impl));

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(alternateImpl));

        vm.prank(_randomCaller);
        assertEq(proxy.implementation(), address(alternateImpl));
    }

    function testAdmin_returnsTheProxyAdminAddress(
        address _randomCaller,
        address _newAdmin
    ) public {
        vm.assume(_randomCaller != _newAdmin);
        vm.assume(_newAdmin != address(0));

        vm.prank(_randomCaller);
        assertEq(proxy.admin(), proxyAdmin);

        vm.prank(proxyAdmin);
        proxy.changeAdmin(_newAdmin);

        vm.prank(_randomCaller);
        assertEq(proxy.admin(), _newAdmin);
    }

    function testChangeAdmin_revertsIfNotCalledByProxyAdmin(
        address _randomCaller,
        address _newAdmin
    ) public {
        vm.assume(_randomCaller != proxyAdmin);

        // This reverts because changeAdmin() does not exist on the implementation, so
        // the delegate call fails
        vm.expectRevert();
        vm.prank(_randomCaller);
        proxy.changeAdmin(_newAdmin);

        // sanity check
        assertEq(proxy.admin(), proxyAdmin);
    }

    function testChangeAdmin_revertsIfNewAdminIsZeroAddress() public {
        vm.prank(proxyAdmin);
        vm.expectRevert("AdminUpgradableProxy: new admin is the zero address");
        proxy.changeAdmin(address(0));
    }

    function testChangeAdmin_succeeds(address _newAdmin) public {
        vm.assume(_newAdmin != proxyAdmin);
        vm.assume(_newAdmin != address(0));

        vm.expectEmit(true, true, true, true);
        emit AdminChanged(proxyAdmin, _newAdmin);

        vm.prank(proxyAdmin);
        proxy.changeAdmin(_newAdmin);

        assertEq(proxy.admin(), _newAdmin);
    }

    function testReceiveNative_revertsIfImplementationDoesntHaveReceiveFunction(
        address _spender
    ) public {
        vm.assume(_spender != address(0));
        vm.assume(_spender != address(proxy));

        vm.deal(_spender, 10 ether);
        vm.startPrank(_spender);

        // MockProxyImplementation.sol does not have a receive function; sanity-check this
        // by sending native token directly to the implementation address
        bool ok;
        (ok, ) = address(impl).call{value: 10 ether}("");
        assertFalse(ok);

        // Transfer native token to the proxy using call(); see: https://github.com/foundry-rs/foundry/discussions/4508
        // This should fail, as the impl does not have a receive function
        (ok, ) = address(proxy).call{value: 10 ether}("");
        assertFalse(ok);

        vm.stopPrank();
        assertEq(address(proxy).balance, 0);
    }

    function testReceiveNative_succeedsIfImplementationHasReceiveFunction(
        address _spender
    ) public {
        vm.assume(_spender != address(0));
        vm.assume(_spender != address(proxy));

        vm.deal(_spender, 10 ether);

        // MockPayableProxyImplementation.sol DOES have a receive function; sanity-check this
        // by sending native token directly to the implementation address
        bool ok;
        vm.prank(_spender);
        (ok, ) = address(payableImpl).call{value: 5 ether}("");
        assertTrue(ok);

        // Now switch over to use the payable impl
        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(payableImpl));

        // Transfer native token using call(); see: https://github.com/foundry-rs/foundry/discussions/4508
        vm.prank(_spender);
        (ok, ) = address(proxy).call{value: 5 ether}("");
        assertTrue(ok);

        assertEq(address(proxy).balance, 5 ether);
    }

    function testUpgradeTo_revertsWhenNotCalledByProxyAdmin(
        address _sender
    ) public {
        vm.assume(_sender != proxyAdmin);

        vm.prank(_sender);
        vm.expectRevert(); // reverts because upgradeTo() does not exist on the implementation
        proxy.upgradeTo(address(alternateImpl));
    }

    function testUpgradeTo_revertsIfNewImplementationIsNotAContract(
        address _randomAddress
    ) public {
        vm.assume(!Address.isContract(_randomAddress));

        vm.prank(proxyAdmin);
        vm.expectRevert(
            "UpgradeableProxy: new implementation is not a contract"
        );
        proxy.upgradeTo(address(_randomAddress));
    }

    function testUpgradeTo_succeeds() public {
        // Sanity check
        assertEq(proxy.implementation(), address(impl));
        assertEq(MockProxyImplementation(address(proxy)).foo(), bytes("bar"));

        vm.expectEmit(true, true, true, true);
        emit Upgraded(address(alternateImpl));

        // Upgrade
        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(alternateImpl));

        assertEq(proxy.implementation(), address(alternateImpl));
        assertEq(
            MockAlternateProxyImplementation(address(proxy)).baz(),
            bytes("qux")
        );
    }

    function testUpgradeToAndCall_revertsWhenNotCalledByProxyAdmin(
        address _sender
    ) public {
        vm.assume(_sender != proxyAdmin);

        vm.prank(_sender);
        vm.expectRevert(); // reverts because upgradeToAndCall() does not exist on the implementation
        proxy.upgradeToAndCall(
            address(alternateImpl),
            abi.encodeWithSelector(
                MockAlternateProxyImplementation
                    .setStoredAddrAlternate
                    .selector,
                address(123)
            )
        );
    }

    function testUpgradeToAndCall_revertsIfNewImplementationIsNotAContract(
        address _randomAddress
    ) public {
        vm.assume(!Address.isContract(_randomAddress));

        vm.prank(proxyAdmin);
        vm.expectRevert(
            "UpgradeableProxy: new implementation is not a contract"
        );
        proxy.upgradeToAndCall(_randomAddress, bytes(""));
    }

    function testUpgradeToAndCall_succeeds(address _randomAddress) public {
        // Sanity check
        assertEq(proxy.implementation(), address(impl));
        assertEq(
            MockProxyImplementation(address(proxy)).storedAddr(),
            address(0)
        );

        vm.expectEmit(true, true, true, true);
        emit Upgraded(address(alternateImpl));

        // Upgrade
        vm.prank(proxyAdmin);
        proxy.upgradeToAndCall(
            address(alternateImpl),
            // Encode a call to set a storage value atomically
            abi.encodeWithSelector(
                MockAlternateProxyImplementation
                    .setStoredAddrAlternate
                    .selector,
                _randomAddress
            )
        );

        assertEq(proxy.implementation(), address(alternateImpl));
        // Check that the proxy delegates to the new impl
        assertEq(
            MockAlternateProxyImplementation(address(proxy)).baz(),
            bytes("qux")
        );
        // Check that the value was stored
        assertEq(
            MockAlternateProxyImplementation(address(proxy))
                .storedAddrAlternate(),
            _randomAddress
        );
    }

    function testDelegatesToImplementationContract() public {
        assertEq(MockProxyImplementation(address(proxy)).foo(), bytes("bar"));

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(alternateImpl));
        assertEq(
            MockAlternateProxyImplementation(address(proxy)).baz(),
            bytes("qux")
        );
    }
}
