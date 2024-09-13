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

contract TokenMessengerV2Test is BaseTokenMessengerTest {
    // Events
    /**
     * @notice Emitted when a DepositForBurn message is sent
     * @param burnToken address of token burnt on source domain
     * @param amount deposit amount
     * @param depositor address where deposit is transferred from
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param destinationDomain destination domain
     * @param destinationTokenMessenger address of TokenMessenger on destination domain as bytes32
     * @param destinationCaller authorized caller as bytes32 of receiveMessage() on destination domain, if not equal to bytes32(0).
     * @param maxFee maximum fee to pay on destination domain, in burnToken
     * @param minFinalityThreshold the minimum finality at which the message should be attested to.
     * @param hook hook target and calldata for execution on destination domain
     */
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
        bytes hook
    );

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

        vm.expectRevert("Invalid hook length");
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

    function testDepositForBurnWithHook_revertsIfHookIsTooShort(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_hook.length > 0 && _hook.length < 32);

        vm.expectRevert("Invalid hook length");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _amount - 1, // maxFee
            _minFinalityThreshold,
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountIsZero(
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

        vm.expectRevert("Amount must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            0, // amount
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfMintRecipientIsZero(
        uint256 _amount,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_hook.length > 32);

        vm.expectRevert("Mint recipient must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            bytes32(0), // mintRecipient
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeEqualsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _amount, // maxFee
            _minFinalityThreshold,
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeExceedsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee > _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hook
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
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

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
            _hook
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
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

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
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsOnFailedTokenTransfer(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

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
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfTokenTransferReverts(
        address _caller,
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);

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
            _hook
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountExceedsMaxBurnAmountPerMessage(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hook.length > 32);
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
            _hook
        );
    }

    function testDepositForBurnWithHook_succeeds(
        uint256 _amount,
        uint256 _burnLimit,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hook,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_amount < _burnLimit);
        vm.assume(_hook.length > 32);
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
            _hook
        );
    }

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
        bytes calldata _hook
    ) internal {
        bytes memory _expectedBurnMessage = BurnMessageV2
            ._formatMessageForRelay(
                messageBodyVersion, // version
                AddressUtils.addressToBytes32(address(localToken)), // burn token
                _mintRecipient, // mint recipient
                _amount, // amount
                AddressUtils.addressToBytes32(_caller), // sender
                _maxFee, // max fee
                _hook
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
            _hook
        );

        vm.prank(_caller);

        if (_hook.length == 0) {
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
                _hook
            );
        }
    }
}
