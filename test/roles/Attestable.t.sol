/*
 * Copyright (c) 2022, Circle Internet Financial Limited.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

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
        address indexed previousAttesterManager,
        address indexed newAttesterManager
    );

    /**
     * @notice Emitted when an attester is enabled
     * @param attester newly enabled attester
     */
    event AttesterEnabled(address indexed attester);

    /**
     * @notice Emitted when an attester is disabled
     * @param attester newly disabled attester
     */
    event AttesterDisabled(address indexed attester);

    /**
     * @notice Emitted when threshold number of attestations (m in m/n multisig) is updated
     * @param oldSignatureThreshold old signature threshold
     * @param newSignatureThreshold new signature threshold
     */
    event SignatureThresholdUpdated(
        uint256 oldSignatureThreshold,
        uint256 newSignatureThreshold
    );

    Attestable attestable;

    function setUp() public {
        vm.prank(owner);
        attestable = new Attestable(attester);
    }

    function testConstructor_setsAttesterManager() public {
        vm.prank(owner);
        Attestable _attester = new Attestable(attester);
        assertEq(_attester.attesterManager(), owner);
    }

    function testUpdateAttesterManager_revertsWhenCalledByNonOwner() public {
        assertEq(attestable.attesterManager(), owner);
        address _newAttesterManager = vm.addr(1506);

        vm.expectRevert("Ownable: caller is not the owner");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), owner);
    }

    function testUpdateAttesterManager_revertsWhenGivenZeroAddress() public {
        assertEq(attestable.attesterManager(), owner);
        address _newAttesterManager = address(0);

        vm.prank(owner);
        vm.expectRevert("Invalid attester manager address");
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), owner);
    }

    function testUpdateAttesterManager_succeeds() public {
        vm.startPrank(owner);

        assertEq(attestable.attesterManager(), owner);
        address _newAttesterManager = vm.addr(1506);

        vm.expectEmit(true, true, true, true);
        emit AttesterManagerUpdated(owner, _newAttesterManager);
        attestable.updateAttesterManager(_newAttesterManager);

        assertEq(attestable.attesterManager(), _newAttesterManager);

        // update again, assert that the previous attesterManager is logged.
        address _secondNewAttesterManager = vm.addr(1507);
        vm.expectEmit(true, true, true, true);
        emit AttesterManagerUpdated(
            _newAttesterManager,
            _secondNewAttesterManager
        );
        attestable.updateAttesterManager(_secondNewAttesterManager);
        assertEq(attestable.attesterManager(), _secondNewAttesterManager);

        vm.stopPrank();
    }

    function testSetSignatureThreshold_revertsIfCalledByNonAttesterManager()
        public
    {
        address _nonAttesterManager = vm.addr(1602);
        vm.prank(_nonAttesterManager);
        vm.expectRevert("Caller not attester manager");
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
        vm.startPrank(owner);

        vm.expectRevert("Invalid signature threshold");
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
        vm.expectRevert("New signature threshold too high");
        _localMessageTransmitter.setSignatureThreshold(2);

        assertEq(_localMessageTransmitter.signatureThreshold(), 1);
    }

    function testSetSignatureThreshold_notEqualToCurrentSignatureThreshold()
        public
    {
        vm.startPrank(owner);

        vm.expectRevert("Signature threshold already set");
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

        vm.expectRevert("Caller not attester manager");
        attestable.enableAttester(_addr);
    }

    function testEnableAttester_rejectsZeroAddress() public {
        vm.startPrank(owner);

        address _newAttesterManager = address(0);
        vm.expectRevert("New attester must be nonzero");
        attestable.enableAttester(_newAttesterManager);

        vm.stopPrank();
    }

    function testEnableAttester_returnsFalseIfAttesterAlreadyExists() public {
        vm.startPrank(owner);

        vm.expectRevert("Attester already enabled");
        attestable.enableAttester(attester);
        assertEq(attestable.getNumEnabledAttesters(), 1);
        assertTrue(attestable.isEnabledAttester(attester));

        vm.stopPrank();
    }

    function testDisableAttester_succeeds() public {
        vm.startPrank(owner);

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

        vm.expectRevert("Caller not attester manager");
        attestable.disableAttester(attester);
    }

    function testDisableAttester_revertsIfOneOrLessAttestersAreEnabled()
        public
    {
        vm.startPrank(owner);

        vm.expectRevert("Too few enabled attesters");
        attestable.disableAttester(attester);

        vm.stopPrank();
    }

    function testDisableAttester_revertsIfSignatureThresholdTooLow() public {
        vm.startPrank(owner);

        attestable.enableAttester(secondAttester);
        attestable.setSignatureThreshold(2);

        vm.expectRevert("Signature threshold is too low");
        attestable.disableAttester(attester);

        vm.stopPrank();
    }

    function testDisableAttester_revertsIfAttesterAlreadyDisabled() public {
        vm.startPrank(owner);

        address _nonAttester = vm.addr(1603);
        // enable second attester, so disabling is allowed
        attestable.enableAttester(secondAttester);

        vm.expectRevert("Attester already disabled");
        attestable.disableAttester(_nonAttester);

        vm.stopPrank();
    }
}
