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
pragma abicoder v2;

import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {TestUtils} from "../TestUtils.sol";
import {MessageV2} from "../../src/messages/v2/MessageV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";

contract MessageTransmitterV2Test is TestUtils {
    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when max message body size is updated
     * @param newMaxMessageBodySize new maximum message body size, in bytes
     */
    event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);

    // ============ Libraries ============

    // Test constants
    uint32 localDomain = 1;

    MessageTransmitterV2 srcMessageTransmitter;

    function setUp() public {
        // message transmitter on source domain
        srcMessageTransmitter = new MessageTransmitterV2(
            localDomain,
            attester,
            maxMessageBodySize,
            version
        );
    }

    function testSendMessage_revertsWhenPaused(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody,
        address _pauser
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_pauser != address(0));
        vm.assume(_destinationDomain != localDomain);

        srcMessageTransmitter.updatePauser(_pauser);

        vm.prank(_pauser);
        srcMessageTransmitter.pause();
        assertTrue(srcMessageTransmitter.paused());

        vm.expectRevert("Pausable: paused");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_revertsWhenSendingToLocalDomain(
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);

        vm.expectRevert("Domain is local domain");
        srcMessageTransmitter.sendMessage(
            localDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_rejectsTooLargeMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_destinationDomain != localDomain);

        bytes memory _messageBody = new bytes(maxMessageBodySize + 1);

        vm.expectRevert("Message body exceeds max size");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_rejectsZeroRecipient(
        uint32 _destinationDomain,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody
    ) public {
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_destinationDomain != localDomain);

        vm.expectRevert("Recipient must be nonzero");
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            bytes32(0), // recipient
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
    }

    function testSendMessage_succeeds(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _messageBody,
        address _sender
    ) public {
        vm.assume(_recipient != bytes32(0));
        vm.assume(_messageBody.length < maxMessageBodySize);
        vm.assume(_destinationDomain != localDomain);

        _sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody,
            _sender
        );
    }

    function testSendMaxMessageBodySize_revertsOnNonOwner(
        uint256 _newMaxMessageBodySize,
        address _notOwner
    ) public {
        vm.assume(_notOwner != srcMessageTransmitter.owner());
        expectRevertWithWrongOwner(_notOwner);
        srcMessageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
    }

    function testSetMaxMessageBodySize_succeeds(
        uint256 _newMaxMessageBodySize
    ) public {
        vm.assume(_newMaxMessageBodySize != maxMessageBodySize);

        // Set new max size
        vm.expectEmit(true, true, true, true);
        emit MaxMessageBodySizeUpdated(_newMaxMessageBodySize);
        srcMessageTransmitter.setMaxMessageBodySize(_newMaxMessageBodySize);
        assertEq(
            srcMessageTransmitter.maxMessageBodySize(),
            _newMaxMessageBodySize
        );
    }

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount,
        address _nonRescuer
    ) public {
        assertContractIsRescuable(
            address(srcMessageTransmitter),
            _rescuer,
            _rescueRecipient,
            _amount,
            _nonRescuer
        );
    }

    function testPausable(
        address _currentPauser,
        address _newPauser,
        address _nonOwner
    ) public {
        vm.assume(_currentPauser != address(0));
        srcMessageTransmitter.updatePauser(_currentPauser);

        assertContractIsPausable(
            address(srcMessageTransmitter),
            _currentPauser,
            _newPauser,
            srcMessageTransmitter.owner(),
            _nonOwner
        );
    }

    function testTransferOwnership_revertsFromNonOwner(
        address _newOwner,
        address _nonOwner
    ) public {
        transferOwnership_revertsFromNonOwner(
            address(srcMessageTransmitter),
            _newOwner,
            _nonOwner
        );
    }

    function testAcceptOwnership_revertsFromNonPendingOwner(
        address _newOwner,
        address _nonOwner
    ) public {
        acceptOwnership_revertsFromNonPendingOwner(
            address(srcMessageTransmitter),
            _newOwner,
            _nonOwner
        );
    }

    function testTransferOwnershipAndAcceptOwnership(address _newOwner) public {
        transferOwnershipAndAcceptOwnership(
            address(srcMessageTransmitter),
            _newOwner
        );
    }

    function testTransferOwnershipWithoutAcceptingThenTransferToNewOwner(
        address _newOwner,
        address _secondNewOwner
    ) public {
        transferOwnershipWithoutAcceptingThenTransferToNewOwner(
            address(srcMessageTransmitter),
            _newOwner,
            _secondNewOwner
        );
    }

    function _sendMessage(
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes memory _messageBody,
        address _sender
    ) internal {
        bytes memory _expectedMessage = MessageV2._formatMessageForRelay(
            version,
            localDomain,
            _destinationDomain,
            AddressUtils.addressToBytes32(_sender),
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );

        assertFalse(srcMessageTransmitter.paused());

        // assert that a MessageSent event was logged with expected message bytes
        vm.prank(_sender);
        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);
        srcMessageTransmitter.sendMessage(
            _destinationDomain,
            _recipient,
            _destinationCaller,
            _minFinalityThreshold,
            _messageBody
        );
        vm.stopPrank();
    }
}
