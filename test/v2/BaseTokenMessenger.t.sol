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

import {Test} from "../../lib/forge-std/src/Test.sol";
import {BaseTokenMessenger} from "../../src/v2/BaseTokenMessenger.sol";
import {TestUtils} from "../TestUtils.sol";

abstract contract BaseTokenMessengerTest is Test, TestUtils {
    // Events

    event RemoteTokenMessengerAdded(uint32 domain, bytes32 tokenMessenger);
    event RemoteTokenMessengerRemoved(uint32 domain, bytes32 tokenMessenger);
    event LocalMinterAdded(address localMinter);
    event LocalMinterRemoved(address localMinter);
    event FeeRecipientSet(address feeRecipient);

    BaseTokenMessenger baseTokenMessenger;

    function setUp() public virtual {
        baseTokenMessenger = BaseTokenMessenger(setUpBaseTokenMessenger());
    }

    function setUpBaseTokenMessenger() internal virtual returns (address);

    function createBaseTokenMessenger(
        address _messageTransmitter,
        uint32 _messageBodyVersion
    ) internal virtual returns (address);

    // Initialization tests
    function testConstructor_setsLocalMessageTransmitter(
        address _messageTransmitter,
        uint32 _messageBodyVersion
    ) public {
        vm.assume(_messageTransmitter != address(0));
        address _tokenMessenger = createBaseTokenMessenger(
            _messageTransmitter,
            _messageBodyVersion
        );

        assertEq(
            BaseTokenMessenger(_tokenMessenger).localMessageTransmitter(),
            _messageTransmitter
        );
    }

    function testConstructor_setsMessageVersion(
        address _messageTransmitter,
        uint32 _messageBodyVersion
    ) public {
        vm.assume(_messageTransmitter != address(0));
        address _tokenMessenger = createBaseTokenMessenger(
            _messageTransmitter,
            _messageBodyVersion
        );

        assertEq(
            uint256(BaseTokenMessenger(_tokenMessenger).messageBodyVersion()),
            uint256(_messageBodyVersion)
        );
    }

    function testConstructor_rejectsZeroAddressLocalMessageTransmitter(
        uint32 _messageBodyVersion
    ) public {
        vm.expectRevert("MessageTransmitter not set");
        createBaseTokenMessenger(address(0), _messageBodyVersion);
    }

    function testAddRemoteTokenMessenger_succeeds(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessengerAddr
    ) public {
        vm.assume(_remoteTokenMessengerAddr != bytes32(0));
        // Sanity check that there is not a token messenger already registered
        assertEq(
            baseTokenMessenger.remoteTokenMessengers(_remoteDomain),
            bytes32(0)
        );

        vm.expectEmit(true, true, true, true);
        emit RemoteTokenMessengerAdded(
            _remoteDomain,
            _remoteTokenMessengerAddr
        );
        baseTokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            _remoteTokenMessengerAddr
        );

        assertEq(
            baseTokenMessenger.remoteTokenMessengers(_remoteDomain),
            _remoteTokenMessengerAddr
        );
    }

    function testAddRemoteTokenMessenger_revertsOnExistingRemoteTokenMessenger(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessengerAddr
    ) public {
        vm.assume(_remoteTokenMessengerAddr != bytes32(0));
        baseTokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            _remoteTokenMessengerAddr
        );

        vm.expectRevert("TokenMessenger already set");
        baseTokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            _remoteTokenMessengerAddr
        );
    }

    function testAddRemoteTokenMessenger_revertsOnZeroAddress(
        uint32 _domain
    ) public {
        vm.expectRevert("bytes32(0) not allowed");
        baseTokenMessenger.addRemoteTokenMessenger(_domain, bytes32(0));
    }

    function testAddRemoteTokenMessenger_revertsOnNonOwner(
        uint32 _domain,
        bytes32 _tokenMessenger,
        address _wrongOwner
    ) public {
        vm.assume(_wrongOwner != baseTokenMessenger.owner());
        expectRevertWithWrongOwner(_wrongOwner);
        baseTokenMessenger.addRemoteTokenMessenger(_domain, _tokenMessenger);
    }

    function testRemoveRemoteTokenMessenger_succeeds(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessenger
    ) public {
        vm.assume(_remoteTokenMessenger != bytes32(0));

        baseTokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            _remoteTokenMessenger
        );

        vm.expectEmit(true, true, true, true);
        emit RemoteTokenMessengerRemoved(_remoteDomain, _remoteTokenMessenger);
        baseTokenMessenger.removeRemoteTokenMessenger(_remoteDomain);
    }

    function testRemoveRemoteTokenMessenger_revertsOnNoTokenMessengerSet(
        uint32 _remoteDomain
    ) public {
        vm.assume(
            baseTokenMessenger.remoteTokenMessengers(_remoteDomain) ==
                bytes32(0)
        );

        vm.expectRevert("No TokenMessenger set");
        baseTokenMessenger.removeRemoteTokenMessenger(_remoteDomain);
    }

    function testRemoveRemoteTokenMessenger_revertsOnNonOwner(
        uint32 _remoteDomain,
        address _wrongOwner
    ) public {
        vm.assume(
            baseTokenMessenger.remoteTokenMessengers(_remoteDomain) ==
                bytes32(0)
        );
        vm.assume(_wrongOwner != baseTokenMessenger.owner());

        expectRevertWithWrongOwner(_wrongOwner);
        baseTokenMessenger.removeRemoteTokenMessenger(_remoteDomain);
    }

    function testAddLocalMinter_succeeds(address _localMinter) public {
        vm.assume(_localMinter != address(0));

        assertEq(address(baseTokenMessenger.localMinter()), address(0));

        _addLocalMinter(_localMinter, baseTokenMessenger);
    }

    function testAddLocalMinter_revertsIfZeroAddress() public {
        vm.expectRevert("Zero address not allowed");
        baseTokenMessenger.addLocalMinter(address(0));
    }

    function testAddLocalMinter_revertsIfAlreadySet(
        address _localMinter
    ) public {
        vm.assume(_localMinter != address(0));

        _addLocalMinter(_localMinter, baseTokenMessenger);

        vm.expectRevert("Local minter is already set.");
        baseTokenMessenger.addLocalMinter(_localMinter);
    }

    function testAddLocalMinter_revertsOnNonOwner(
        address _localMinter,
        address _notOwner
    ) public {
        vm.assume(_localMinter != address(0));
        vm.assume(_notOwner != baseTokenMessenger.owner());

        expectRevertWithWrongOwner(_notOwner);
        baseTokenMessenger.addLocalMinter(_localMinter);
    }

    function testRemoveLocalMinter_succeeds(address _localMinter) public {
        vm.assume(_localMinter != address(0));

        _addLocalMinter(_localMinter, baseTokenMessenger);

        vm.expectEmit(true, true, true, true);
        emit LocalMinterRemoved(_localMinter);
        baseTokenMessenger.removeLocalMinter();
    }

    function testRemoveLocalMinter_revertsIfNoLocalMinterSet() public {
        vm.expectRevert("No local minter is set.");
        baseTokenMessenger.removeLocalMinter();
    }

    function testRemoveLocalMinter_revertsOnNonOwner(address _notOwner) public {
        vm.assume(_notOwner != baseTokenMessenger.owner());
        expectRevertWithWrongOwner(_notOwner);
        baseTokenMessenger.removeLocalMinter();
    }

    function testSetFeeRecipient_revertsOnNonOwner(
        address _notOwner,
        address _feeRecipient
    ) public {
        vm.assume(_notOwner != baseTokenMessenger.owner());
        expectRevertWithWrongOwner(_notOwner);
        baseTokenMessenger.setFeeRecipient(_feeRecipient);
    }

    function testSetFeeRecipient_revertsIfFeeRecipientIsZeroAddress() public {
        vm.expectRevert("Zero address not allowed");
        baseTokenMessenger.setFeeRecipient(address(0));
    }

    function testSetFeeRecipient_succeeds(address _feeRecipient) public {
        vm.assume(_feeRecipient != address(0));

        vm.expectEmit(true, true, true, true);
        emit FeeRecipientSet(_feeRecipient);
        baseTokenMessenger.setFeeRecipient(_feeRecipient);
    }

    // Ownable tests

    function testTransferOwnershipAndAcceptOwnership_succeeds(
        address _newOwner
    ) public {
        vm.assume(_newOwner != baseTokenMessenger.owner());
        transferOwnershipAndAcceptOwnership(
            address(baseTokenMessenger),
            _newOwner
        );
    }

    function testTransferOwnership_revertsOnNonOwner(
        address _notOwner,
        address _newOwner
    ) public {
        vm.assume(_notOwner != baseTokenMessenger.owner());
        transferOwnershipFailsIfNotOwner(
            address(baseTokenMessenger),
            _notOwner,
            _newOwner
        );
    }

    function testAcceptOwnership_revertsOnNonPendingOwner(
        address _newOwner,
        address _otherAccount
    ) public {
        vm.assume(_newOwner != _otherAccount);
        acceptOwnershipFailsIfNotPendingOwner(
            address(baseTokenMessenger),
            _newOwner,
            _otherAccount
        );
    }

    function testTransferOwnershipWithoutAcceptingThenTransferToNewOwner_succeeds(
        address _newOwner,
        address _secondNewOwner
    ) public {
        transferOwnershipWithoutAcceptingThenTransferToNewOwner(
            address(baseTokenMessenger),
            _newOwner,
            _secondNewOwner
        );
    }

    // Rescuable tests

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount,
        address _nonRescuer
    ) public {
        assertContractIsRescuable(
            address(baseTokenMessenger),
            _rescuer,
            _rescueRecipient,
            _amount,
            _nonRescuer
        );
    }

    // Denylistable Tests

    function testDenylistable(
        address _randomAddress,
        address _newDenylister,
        address _nonOwner
    ) public {
        assertContractIsDenylistable(
            address(baseTokenMessenger),
            _randomAddress,
            _newDenylister,
            _nonOwner
        );
    }

    // Test utils

    function _addLocalMinter(
        address _localMinter,
        BaseTokenMessenger _tokenMessenger
    ) internal {
        vm.expectEmit(true, true, true, true);
        emit LocalMinterAdded(_localMinter);
        _tokenMessenger.addLocalMinter(_localMinter);
        assertEq(address(_tokenMessenger.localMinter()), _localMinter);
    }
}
