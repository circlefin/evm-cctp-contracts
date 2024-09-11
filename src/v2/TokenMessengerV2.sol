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

import {BaseTokenMessenger} from "./BaseTokenMessenger.sol";
import {ITokenMinter} from "../interfaces/ITokenMinter.sol";
import {IMintBurnToken} from "../interfaces/IMintBurnToken.sol";
import {BurnMessageV2} from "../messages/v2/BurnMessageV2.sol";
import {Message} from "../messages/Message.sol";
import {MessageTransmitterV2} from "./MessageTransmitterV2.sol";

/**
 * @title TokenMessengerV2
 * @notice Sends messages and receives messages to/from MessageTransmitters
 * and to/from TokenMinters
 */
contract TokenMessengerV2 is BaseTokenMessenger {
    // ============ Events ============
    /**
     * @notice Emitted when a DepositForBurn message is sent
     * @param burnToken address of token burnt on source domain
     * @param amount deposit amount
     * @param depositor address where deposit is transferred from
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param destinationDomain destination domain
     * @param destinationTokenMessenger address of TokenMessenger on destination domain as bytes32
     * @param destinationCaller authorized caller as bytes32 of receiveMessage() on destination domain.
     * If equal to bytes32(0), any address can broadcast the message.
     * @param maxFee maximum fee to pay on destination domain, in units of burnToken
     * @param minFinalityThreshold the minimum finality at which the message should be attested to.
     * @param hook target and calldata for execution on destination domain
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

    // ============ Libraries ============

    // ============ State Variables ============
    uint32 public immutable MIN_HOOK_LENGTH = 32;

    // ============ Modifiers ============

    // ============ Constructor ============
    /**
     * @param _messageTransmitter Message transmitter address
     * @param _messageBodyVersion Message body version
     */
    constructor(
        address _messageTransmitter,
        uint32 _messageBodyVersion
    ) BaseTokenMessenger(_messageTransmitter, _messageBodyVersion) {}

    // ============ External Functions  ============
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - maxFee is greater than or equal to the amount.
     * - MessageTransmitter#sendMessage reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
     * any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external {
        bytes calldata _emptyHook = msg.data[0:0];
        _depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            _emptyHook
        );
    }

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - hook appears invalid, such as being less than 32 bytes in length
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - fee is greater than or equal to the amount.
     * - MessageTransmitter#sendMessage reverts.
     * @dev Note that even if the hook reverts on the destination domain, the mint will still proceed.
     * @dev Hook formatting:
     * - TODO: STABLE-7280
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
     * any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     * @param hook hook to execute on destination domain. Must be 32-bytes length or more.
     */
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hook
    ) external {
        require(hook.length >= MIN_HOOK_LENGTH, "Invalid hook length");

        _depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            hook
        );
    }

    // ============ Internal Utils ============
    function _depositForBurn(
        uint256 _amount,
        uint32 _destinationDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hook
    ) internal {
        require(_amount > 0, "Amount must be nonzero");
        require(_mintRecipient != bytes32(0), "Mint recipient must be nonzero");
        require(_maxFee < _amount, "Max fee must be less than amount");

        bytes32 _destinationTokenMessenger = _getRemoteTokenMessenger(
            _destinationDomain
        );

        // Deposit and burn tokens
        _depositAndBurnTokens(_burnToken, msg.sender, _amount);

        // Format message body
        bytes memory _burnMessage = BurnMessageV2._formatMessage(
            messageBodyVersion,
            Message.addressToBytes32(_burnToken),
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msg.sender),
            _maxFee,
            _hook
        );

        // Send message
        MessageTransmitterV2(localMessageTransmitter).sendMessage(
            _destinationDomain,
            _destinationTokenMessenger,
            _destinationCaller,
            _minFinalityThreshold,
            _burnMessage
        );

        emit DepositForBurn(
            _burnToken,
            _amount,
            msg.sender,
            _mintRecipient,
            _destinationDomain,
            _destinationTokenMessenger,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hook
        );
    }

    function _depositAndBurnTokens(
        address _burnToken,
        address _from,
        uint256 _amount
    ) internal {
        ITokenMinter _localMinter = _getLocalMinter();
        IMintBurnToken _mintBurnToken = IMintBurnToken(_burnToken);
        require(
            _mintBurnToken.transferFrom(_from, address(_localMinter), _amount),
            "Transfer operation failed"
        );
        _localMinter.burn(_burnToken, _amount);
    }
}
