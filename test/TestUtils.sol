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
import "./mocks/MockMintBurnToken.sol";

contract TestUtils is Test {
    /**
     * @notice Emitted when a local CircleBridge is added
     * @param _localCircleBridge address of local CircleBridge
     * @notice Emitted when a local CircleBridge is added
     */
    event LocalCircleBridgeAdded(address _localCircleBridge);

    /**
     * @notice Emitted when a local CircleBridge is removed
     * @param _localCircleBridge address of local CircleBridge
     * @notice Emitted when a local CircleBridge is removed
     */
    event LocalCircleBridgeRemoved(address _localCircleBridge);

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

    function addLocalCircleBridge(
        CircleMinter _circleMinter,
        address _localCircleBridge
    ) public {
        assertEq(_circleMinter.localCircleBridge(), address(0));

        vm.expectEmit(true, true, true, true);
        emit LocalCircleBridgeAdded(_localCircleBridge);
        _circleMinter.addLocalCircleBridge(_localCircleBridge);

        assertEq(_circleMinter.localCircleBridge(), _localCircleBridge);
    }

    function removeLocalBridge(CircleMinter _circleMinter) public {
        address _currentCircleBridge = _circleMinter.localCircleBridge();
        assertTrue(_currentCircleBridge != address(0));

        vm.expectEmit(true, true, true, true);
        emit LocalCircleBridgeRemoved(_currentCircleBridge);
        _circleMinter.removeLocalCircleBridge();

        assertEq(_circleMinter.localCircleBridge(), address(0));
    }

    function expectRevertWithWrongOwner() public {
        address nonOwner = vm.addr(1510);
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function assertContractIsRescuable(
        address _rescuableContractAddress,
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount
    ) public {
        // Send erc20 to _rescuableContractAddress
        Rescuable _rescuableContract = Rescuable(_rescuableContractAddress);
        MockMintBurnToken _mockMintBurnToken = new MockMintBurnToken();

        // _rescueRecipient's initial balance of _mockMintBurnToken is 0
        assertEq(_mockMintBurnToken.balanceOf(_rescueRecipient), 0);

        // Mint _mockMintBurnToken to _rescueRecipient
        _mockMintBurnToken.mint(_rescueRecipient, _amount);

        // _rescueRecipient accidentally sends _mockMintBurnToken to the _rescuableContractAddress
        vm.prank(_rescueRecipient);
        _mockMintBurnToken.transfer(_rescuableContractAddress, _amount);
        assertEq(
            _mockMintBurnToken.balanceOf(_rescuableContractAddress),
            _amount
        );

        // (Updating rescuer to zero-address is not permitted)
        if (_rescuer != address(0)) {
            _rescuableContract.updateRescuer(_rescuer);
        }

        // Rescue erc20 to _rescueRecipient
        vm.prank(_rescuer);
        _rescuableContract.rescueERC20(
            _mockMintBurnToken,
            _rescueRecipient,
            _amount
        );

        // Assert funds are rescued
        assertEq(_mockMintBurnToken.balanceOf(_rescueRecipient), _amount);
    }

    function transferOwnership(
        address _ownableContractAddress,
        address _newOwner
    ) public {
        Ownable _ownableContract = Ownable(_ownableContractAddress);
        address initialOwner = _ownableContract.owner();
        _ownableContract.transferOwnership(_newOwner);
        assertEq(_ownableContract.owner(), _newOwner);
        assertFalse(_newOwner == initialOwner);
    }
}
