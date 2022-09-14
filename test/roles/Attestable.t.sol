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
import "../../src/MessageTransmitter.sol";
import "../TestUtils.sol";

contract AttestableTest is Test, TestUtils {
    /**
     * @dev Emitted when attester manager address is updated
     * @param previousAttesterManager representing the address of the previous attester manager
     * @param newAttesterManager representing the address of the new attester manager
     */
    event AttesterManagerUpdated(
        address previousAttesterManager,
        address newAttesterManager
    );

    /**
     * @notice Emitted when an attester is enabled
     * @param attester newly enabled attester
     */
    event AttesterEnabled(address attester);

    /**
     * @notice Emitted when an attester is disabled
     * @param attester newly disabled attester
     */
    event AttesterDisabled(address attester);

    /**
     * @notice Emitted when threshold number of attestations (m in m/n multisig) is updated
     * @param oldSignatureThreshold old signature threshold
     * @param newSignatureThreshold new signature threshold
     */
    event SignatureThresholdUpdated(
        uint256 oldSignatureThreshold,
        uint256 newSignatureThreshold
    );

    address initialAttesterManager = vm.addr(1505);
    Attestable attestable;

    function setUp() public {
        vm.prank(initialAttesterManager);
        attestable = new Attestable(attester);
    }

    function testConstructor_setsAttesterManager() public {
        vm.prank(initialAttesterManager);
        Attestable _attester = new Attestable(attester);
        assertEq(_attester.attesterManager(), initialAttesterManager);
    }

    function testUpdateAttesterManager_revertsWhenCalledByWrongAttesterManager()
        public
    {
        assertEq(attestable.attesterManager(), initialAttesterManager);
        address _newAttesterManager = vm.addr(1506);

        vm.expectRevert("Attestable: caller is not the attester manager");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), initialAttesterManager);
    }

    function testUpdateAttesterManager_revertsWhenGivenZeroAddress() public {
        assertEq(attestable.attesterManager(), initialAttesterManager);
        address _newAttesterManager = address(0);

        vm.prank(initialAttesterManager);
        vm.expectRevert("Attestable: new attester manager is the zero address");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), initialAttesterManager);
    }

    function testUpdateAttesterManager_succeeds() public {
        vm.startPrank(initialAttesterManager);

        assertEq(attestable.attesterManager(), initialAttesterManager);
        address _newAttesterManager = vm.addr(1506);

        vm.expectEmit(true, true, true, true);
        emit AttesterManagerUpdated(_newAttesterManager, _newAttesterManager);
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), _newAttesterManager);

        vm.stopPrank();
    }

    function testSetSignatureThreshold_revertsIfCalledByNonAttesterManager()
        public
    {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);
        vm.expectRevert("Attestable: caller is not the attester manager");
        attestable.setSignatureThreshold(1);
    }

    function testSetSignatureThreshold_succeeds() public {
        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );
        assertEq(_localMessageTransmitter.signatureThreshold(), 1);

        // enable second attester, so increasing threshold is allowed
        _localMessageTransmitter.enableAttester(secondAttester);

        vm.expectEmit(true, true, true, true);
        emit SignatureThresholdUpdated(1, 2);

        // update signatureThreshold to 2
        _localMessageTransmitter.setSignatureThreshold(2);
        assertEq(_localMessageTransmitter.signatureThreshold(), 2);
    }

    function testSetSignatureThreshold_rejectsZeroValue() public {
        vm.startPrank(initialAttesterManager);

        vm.expectRevert("New signature threshold must be nonzero");
        attestable.setSignatureThreshold(0);

        vm.stopPrank();
    }

    function testSetSignatureThreshold_cannotExceedNumberOfEnabledAttesters()
        public
    {
        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );
        assertEq(_localMessageTransmitter.signatureThreshold(), 1);

        // fail to update signatureThreshold to 2
        vm.expectRevert(
            "New signature threshold cannot exceed the number of enabled attesters"
        );
        _localMessageTransmitter.setSignatureThreshold(2);

        assertEq(_localMessageTransmitter.signatureThreshold(), 1);
    }

    function testSetSignatureThreshold_notEqualToCurrentSignatureThreshold()
        public
    {
        vm.startPrank(initialAttesterManager);

        vm.expectRevert(
            "New signature threshold must not equal current signature threshold"
        );
        attestable.setSignatureThreshold(1);

        vm.stopPrank();
    }

    function testGetEnabledAttester_succeeds() public {
        assertEq(attestable.getEnabledAttester(0), attester);
    }

    function testGetEnabledAttester_reverts() public {
        vm.expectRevert("EnumerableSet: index out of bounds");
        attestable.getEnabledAttester(1);
    }

    function testEnableAttester_succeeds() public {
        address _newAttester = vm.addr(1601);

        MessageTransmitter _localMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );

        assertFalse(_localMessageTransmitter.isEnabledAttester(_newAttester));

        assertEq(_localMessageTransmitter.getNumEnabledAttesters(), 1);

        vm.expectEmit(true, true, true, true);
        emit AttesterEnabled(_newAttester);
        _localMessageTransmitter.enableAttester(_newAttester);
        assertTrue(_localMessageTransmitter.isEnabledAttester(_newAttester));

        assertEq(_localMessageTransmitter.getNumEnabledAttesters(), 2);
    }

    function testEnableAttester_revertsIfCalledByNonAttesterManager(
        address _addr
    ) public {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);

        vm.expectRevert("Attestable: caller is not the attester manager");
        attestable.enableAttester(_addr);
    }

    function testEnableAttester_rejectsZeroAddress() public {
        vm.startPrank(initialAttesterManager);

        address _newAttesterManager = address(0);
        vm.expectRevert("New attester must be nonzero");
        attestable.enableAttester(_newAttesterManager);

        vm.stopPrank();
    }

    function testEnableAttester_returnsFalseIfAttesterAlreadyExists() public {
        vm.startPrank(initialAttesterManager);

        vm.expectRevert("Attester already enabled");
        attestable.enableAttester(attester);
        assertEq(attestable.getNumEnabledAttesters(), 1);
        assertTrue(attestable.isEnabledAttester(attester));

        vm.stopPrank();
    }

    function testDisableAttester_succeeds() public {
        vm.startPrank(initialAttesterManager);

        // enable second attester, so disabling is allowed
        attestable.enableAttester(secondAttester);
        assertEq(attestable.getNumEnabledAttesters(), 2);

        vm.expectEmit(true, true, true, true);
        emit AttesterDisabled(attester);
        attestable.disableAttester(attester);
        assertEq(attestable.getNumEnabledAttesters(), 1);
        assertFalse(attestable.isEnabledAttester(attester));

        vm.stopPrank();
    }

    function testDisableAttester_revertsIfCalledByNonAttesterManager() public {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);

        vm.expectRevert("Attestable: caller is not the attester manager");
        attestable.disableAttester(attester);
    }

    function testDisableAttester_revertsIfOneOrLessAttestersAreEnabled()
        public
    {
        vm.startPrank(initialAttesterManager);

        vm.expectRevert(
            "Unable to disable attester because 1 or less attesters are enabled"
        );
        attestable.disableAttester(attester);

        vm.stopPrank();
    }

    function testDisableAttester_revertsIfSignatureThresholdTooLow() public {
        vm.startPrank(initialAttesterManager);

        attestable.enableAttester(secondAttester);
        attestable.setSignatureThreshold(2);

        vm.expectRevert(
            "Unable to disable attester because signature threshold is too low"
        );
        attestable.disableAttester(attester);

        vm.stopPrank();
    }

    function testDisableAttester_revertsIfAttesterAlreadyDisabled() public {
        vm.startPrank(initialAttesterManager);

        address _nonAttester = vm.addr(1603);
        // enable second attester, so disabling is allowed
        attestable.enableAttester(secondAttester);

        vm.expectRevert("Attester already disabled");
        attestable.disableAttester(_nonAttester);

        vm.stopPrank();
    }
}
