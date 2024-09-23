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

import {BaseTokenMessengerTest} from "./BaseTokenMessenger.t.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";
import {MockMintBurnToken} from "../mocks/MockMintBurnToken.sol";
import {TokenMinter} from "../../src/TokenMinter.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {BurnMessageV2} from "../../src/messages/v2/BurnMessageV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";

contract TokenMessengerV2Test is BaseTokenMessengerTest {
    // Events
    event DepositForBurn(
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 indexed minFinalityThreshold,
        bytes hookData
    );

    event MintAndWithdraw(
        address indexed mintRecipient,
        uint256 amount,
        address indexed mintToken
    );

    // Libraries
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;

    // Constants
    uint32 remoteDomain = 1;
    uint32 messageBodyVersion = 2;

    address localMessageTransmitter = address(10);
    address remoteMessageTransmitter = address(20);

    TokenMessengerV2 localTokenMessenger;

    address remoteTokenMessageger = address(30);
    bytes32 remoteTokenMessengerAddr;

    address remoteTokenAddr = address(40);

    MockMintBurnToken localToken = new MockMintBurnToken();
    TokenMinter localTokenMinter = new TokenMinter(tokenController);

    function setUp() public override {
        // TokenMessenger under test
        localTokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );
        // Add a local minter
        localTokenMessenger.addLocalMinter(address(localTokenMinter));

        remoteTokenMessengerAddr = AddressUtils.addressToBytes32(
            remoteTokenMessageger
        );

        // Register remote token messenger
        localTokenMessenger.addRemoteTokenMessenger(
            remoteDomain,
            remoteTokenMessengerAddr
        );

        linkTokenPair(
            localTokenMinter,
            address(localToken),
            remoteDomain,
            AddressUtils.addressToBytes32(remoteTokenAddr)
        );

        localTokenMinter.addLocalTokenMessenger(address(localTokenMessenger));

        super.setUp();
    }

    // BaseTokenMessengerTest overrides

    function setUpBaseTokenMessenger() internal override returns (address) {
        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );
        return address(_tokenMessenger);
    }

    function createBaseTokenMessenger(
        address _localMessageTransmitter,
        uint32 _messageBodyVersion
    ) internal override returns (address) {
        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            _localMessageTransmitter,
            _messageBodyVersion
        );
        return address(_tokenMessenger);
    }

    // Tests

    function testDepositForBurn_revertsIfTransferAmountIsZero(
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Amount must be nonzero");
        localTokenMessenger.depositForBurn(
            0, // amount
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfMintRecipientIsZero(
        uint256 _amount,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);

        vm.expectRevert("Mint recipient must be nonzero");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            bytes32(0), // mintRecipient
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfFeeEqualsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _amount, // maxFee
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfFeeExceedsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee > _amount);
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfNoRemoteTokenMessengerExistsForDomain(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        vm.expectRevert("No TokenMessenger for domain");
        _tokenMessenger.depositForBurn(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfLocalMinterIsNotSet(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        _tokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            remoteTokenMessengerAddr
        );

        vm.expectRevert("Local minter is not set");
        _tokenMessenger.depositForBurn(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsOnFailedTokenTransfer(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        vm.mockCall(
            address(localToken),
            abi.encodeWithSelector(MockMintBurnToken.transferFrom.selector),
            abi.encode(false)
        );
        vm.expectRevert("Transfer operation failed");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTokenTransferReverts(
        address _caller,
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        // TransferFrom will revert, as localTokenMessenger has no allowance
        assertEq(
            localToken.allowance(_caller, address(localTokenMessenger)),
            0
        );

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTransferAmountExceedsMaxBurnAmountPerMessage(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);
        vm.assume(_caller != address(0));

        _setupDepositForBurn(_caller, _amount, _amount - 1);

        vm.prank(_caller);
        vm.expectRevert("Burn amount exceeds per tx limit");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_succeeds(
        uint256 _amount,
        uint256 _burnLimit,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_amount < _burnLimit);
        vm.assume(_caller != address(0));

        uint256 _maxFee = _amount - 1;

        _setupDepositForBurn(_caller, _amount, _burnLimit);

        _depositForBurn(
            _caller,
            _mintRecipient,
            _destinationCaller,
            _amount,
            _maxFee,
            _minFinalityThreshold,
            msg.data[0:0]
        );
    }

    function testDepositForBurnWithHook_revertsIfHookIsEmpty(
        uint256 _amount,
        uint256 _maxFee,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);

        vm.expectRevert("Hook data is empty");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            bytes("")
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountIsZero(
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Amount must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            0, // amount
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfMintRecipientIsZero(
        uint256 _amount,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Mint recipient must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            bytes32(0), // mintRecipient
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeEqualsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _amount, // maxFee
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeExceedsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee > _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfNoRemoteTokenMessengerExistsForDomain(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        vm.expectRevert("No TokenMessenger for domain");
        _tokenMessenger.depositForBurnWithHook(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfLocalMinterIsNotSet(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        _tokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            remoteTokenMessengerAddr
        );

        vm.expectRevert("Local minter is not set");
        _tokenMessenger.depositForBurnWithHook(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsOnFailedTokenTransfer(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.mockCall(
            address(localToken),
            abi.encodeWithSelector(MockMintBurnToken.transferFrom.selector),
            abi.encode(false)
        );
        vm.expectRevert("Transfer operation failed");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfTokenTransferReverts(
        address _caller,
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        // TransferFrom will revert, as localTokenMessenger has no allowance
        assertEq(
            localToken.allowance(_caller, address(localTokenMessenger)),
            0
        );

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountExceedsMaxBurnAmountPerMessage(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);
        vm.assume(_caller != address(0));

        _setupDepositForBurn(_caller, _amount, _amount - 1);

        vm.prank(_caller);
        vm.expectRevert("Burn amount exceeds per tx limit");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_succeeds(
        uint256 _amount,
        uint256 _burnLimit,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_amount < _burnLimit);
        vm.assume(_hookData.length > 0);
        vm.assume(_caller != address(0));

        uint256 _maxFee = _amount - 1;

        _setupDepositForBurn(_caller, _amount, _burnLimit);

        _depositForBurn(
            _caller,
            _mintRecipient,
            _destinationCaller,
            _amount,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfCallerIsNotLocalMessageTransmitter(
        uint32 _remoteDomain,
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody,
        address _caller
    ) public {
        vm.assume(_caller != localMessageTransmitter);

        vm.expectRevert("Invalid message transmitter");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMessageSenderIsNotRemoteTokenMessengerForKnownDomain(
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_sender != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain, // known domain, but unknown remote token messenger addr
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMessageSenderIsKnownRemoteTokenMessengerForUnknownDomain(
        uint32 _remoteDomain,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            remoteTokenMessengerAddr, // known token messenger, but unknown domain
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsForUnknownRemoteTokenMessengersAndRemoteDomains(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessenger,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);
        vm.assume(_remoteTokenMessenger != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            _remoteTokenMessenger,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsOnTooShortMessage(
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        // See: BurnMessageV2#HOOK_DATA_INDEX
        vm.assume(_messageBody.length < 228);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid message: too short");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsOnInvalidMessageBodyVersion(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_version != localTokenMessenger.messageBodyVersion());

        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid message body version");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfNoLocalMinterIsSet(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        assertTrue(address(localTokenMessenger.localMinter()) != address(0));

        // Remove local minter
        localTokenMessenger.removeLocalMinter();

        assertEq(address(localTokenMessenger.localMinter()), address(0));

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Local minter is not set");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMintReverts(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        // Mock a failing call to TokenMinter mint()
        bytes memory _call = abi.encodeWithSelector(
            TokenMinter.mint.selector,
            remoteDomain,
            _burnToken,
            AddressUtils.bytes32ToAddress(_mintRecipient),
            _amount
        );
        vm.mockCallRevert(
            address(localTokenMinter),
            _call,
            "Testing: token minter failed"
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Testing: token minter failed");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeeds(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= 2000);

        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            localTokenMessenger.messageBodyVersion(),
            AddressUtils.addressToBytes32(remoteTokenAddr),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    // Test helpers

    function _setupDepositForBurn(
        address _caller,
        uint256 _amount,
        uint256 _maxBurnAmount
    ) internal {
        localToken.mint(_caller, _amount);

        vm.prank(_caller);
        localToken.approve(address(localTokenMessenger), _amount);

        vm.prank(tokenController);
        localTokenMinter.setMaxBurnAmountPerMessage(
            address(localToken),
            _maxBurnAmount
        );
    }

    function _depositForBurn(
        address _caller,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _amount,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) internal {
        bytes memory _expectedBurnMessage = BurnMessageV2
            ._formatMessageForRelay(
                localTokenMessenger.messageBodyVersion(), // version
                AddressUtils.addressToBytes32(address(localToken)), // burn token
                _mintRecipient, // mint recipient
                _amount, // amount
                AddressUtils.addressToBytes32(_caller), // sender
                _maxFee, // max fee
                _hookData
            );

        // expect burn() on localTokenMinter
        vm.expectCall(
            address(localTokenMinter),
            abi.encodeWithSelector(
                localTokenMinter.burn.selector,
                address(localToken),
                _amount
            )
        );

        // expect sendMessage() on localMessageTransmitter
        vm.expectCall(
            address(localMessageTransmitter),
            abi.encodeWithSelector(
                MessageTransmitterV2.sendMessage.selector,
                destinationDomain,
                remoteTokenMessengerAddr,
                _destinationCaller,
                _minFinalityThreshold,
                _expectedBurnMessage
            )
        );

        // Mock an empty response from messageTransmitter
        vm.mockCall(
            address(localMessageTransmitter),
            abi.encodeWithSelector(MessageTransmitterV2.sendMessage.selector),
            bytes("")
        );

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit DepositForBurn(
            address(localToken),
            _amount,
            _caller,
            _mintRecipient,
            destinationDomain,
            remoteTokenMessengerAddr,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );

        vm.prank(_caller);

        if (_hookData.length == 0) {
            localTokenMessenger.depositForBurn(
                _amount,
                destinationDomain,
                _mintRecipient,
                address(localToken),
                _destinationCaller,
                _maxFee,
                _minFinalityThreshold
            );
        } else {
            localTokenMessenger.depositForBurnWithHook(
                _amount,
                destinationDomain,
                _mintRecipient,
                address(localToken),
                _destinationCaller,
                _maxFee,
                _minFinalityThreshold,
                _hookData
            );
        }
    }

    function _handleReceiveMessage(
        uint32 _remoteDomain,
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes memory _messageBody
    ) internal {
        bytes29 _msg = _messageBody.ref(0);
        address _mintRecipient = AddressUtils.bytes32ToAddress(
            _msg._getMintRecipient()
        );
        uint256 _amount = _msg._getAmount();

        // Sanity checks to ensure this is being called with appropriate inputs
        assertEq(
            uint256(localTokenMessenger.messageBodyVersion()),
            uint256(_msg._getVersion())
        );
        assertEq(uint256(_remoteDomain), uint256(remoteDomain));
        assertEq(_sender, remoteTokenMessengerAddr);
        assertEq(
            AddressUtils.bytes32ToAddress(_msg._getBurnToken()),
            remoteTokenAddr
        );

        // Sanity check that the starting balance of mintRecipient is 0
        assertEq(localToken.balanceOf(_mintRecipient), 0);

        // Expect that mint() be called 1x on TokenMinter
        bytes memory _encodedMintCall = abi.encodeWithSelector(
            TokenMinter.mint.selector,
            _remoteDomain,
            _msg._getBurnToken(),
            _mintRecipient,
            _amount
        );
        vm.expectCall(address(localTokenMinter), _encodedMintCall, 1);

        // Expect MintAndWithdraw to be emitted
        vm.expectEmit(true, true, true, true);
        emit MintAndWithdraw(_mintRecipient, _amount, address(localToken));

        // Execute handleReceive()
        vm.prank(localMessageTransmitter);

        bool _result;
        if (_finalityThresholdExecuted >= 2000) {
            _result = localTokenMessenger.handleReceiveFinalizedMessage(
                _remoteDomain,
                _sender,
                _finalityThresholdExecuted,
                _messageBody
            );
        } else {
            _result = localTokenMessenger.handleReceiveUnfinalizedMessage(
                _remoteDomain,
                _sender,
                _finalityThresholdExecuted,
                _messageBody
            );
        }

        assertTrue(_result);

        // Check balance after
        assertEq(_msg._getAmount(), localToken.balanceOf(_mintRecipient));
    }
}
