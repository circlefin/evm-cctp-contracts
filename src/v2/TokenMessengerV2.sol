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
import {ITokenMinterV2} from "../interfaces/v2/ITokenMinterV2.sol";
import {AddressUtils} from "../messages/v2/AddressUtils.sol";
import {IRelayerV2} from "../interfaces/v2/IRelayerV2.sol";
import {IMessageHandlerV2} from "../interfaces/v2/IMessageHandlerV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {BurnMessageV2} from "../messages/v2/BurnMessageV2.sol";
import {Initializable} from "./Initializable.sol";

/**
 * @title TokenMessengerV2
 * @notice Sends messages and receives messages to/from MessageTransmitters
 * and to/from TokenMinters
 */
contract TokenMessengerV2 is IMessageHandlerV2, BaseTokenMessenger {
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
     * @param hookData optional hook for execution on destination domain
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
        bytes hookData
    );

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;

    // ============ State Variables ============
    uint32 public immutable MINIMUM_SUPPORTED_FINALITY_THRESHOLD = 1000;

    // ============ Constructor ============
    /**
     * @param _messageTransmitter Message transmitter address
     * @param _messageBodyVersion Message body version
     */
    constructor(
        address _messageTransmitter,
        uint32 _messageBodyVersion
    ) BaseTokenMessenger(_messageTransmitter, _messageBodyVersion) {
        _disableInitializers();
    }

    // ============ Initializers ============
    /**
     * @notice Initializes the contract
     * @dev Reverts if `owner_` is the zero address
     * @dev Reverts if `rescuer_` is the zero address
     * @dev Reverts if `feeRecipient_` is the zero address
     * @dev Reverts if `denylister_` is the zero address
     * @dev Reverts if `tokenMinter_` is the zero address
     * @dev Reverts if `remoteDomains_` is zero-length
     * @dev Reverts if `remoteDomains_` and `remoteTokenMessengers_` are unequal length
     * @dev Each remoteTokenMessenger address must correspond to the remote domain at the same
     * index in respective arrays.
     * @param owner_ Owner address
     * @param rescuer_ Rescuer address
     * @param feeRecipient_ FeeRecipient address
     * @param denylister_ Denylister address
     * @param tokenMinter_ Local token minter address
     * @param remoteDomains_ Array of remote domains to configure
     * @param remoteTokenMessengers_ Array of remote token messenger addresses
     */
    function initialize(
        address owner_,
        address rescuer_,
        address feeRecipient_,
        address denylister_,
        address tokenMinter_,
        uint32[] calldata remoteDomains_,
        bytes32[] calldata remoteTokenMessengers_
    ) external initializer {
        require(owner_ != address(0), "Owner is the zero address");
        require(tokenMinter_ != address(0), "TokenMinter is the zero address");
        require(
            remoteDomains_.length == remoteTokenMessengers_.length &&
                remoteDomains_.length > 0,
            "Invalid remote domain configuration"
        );

        // Roles
        _transferOwnership(owner_);
        _updateRescuer(rescuer_);
        _updateDenylister(denylister_);
        _setFeeRecipient(feeRecipient_);

        localMinter = ITokenMinterV2(tokenMinter_);

        // Remote messenger configuration
        for (uint256 i; i < remoteDomains_.length; i++) {
            require(
                remoteTokenMessengers_[i] != bytes32(0),
                "Invalid TokenMessenger"
            );
            uint32 _remoteDomain = remoteDomains_[i];
            bytes32 _remoteTokenMessenger = remoteTokenMessengers_[i];
            remoteTokenMessengers[_remoteDomain] = _remoteTokenMessenger;
        }
    }

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
    ) external notDenylistedCallers {
        bytes calldata _emptyHookData = msg.data[0:0];
        _depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            _emptyHookData
        );
    }

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - hookData is zero-length
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - fee is greater than or equal to the amount.
     * - MessageTransmitter#sendMessage reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
     * any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     * @param hookData hook data to append to burn message for interpretation on destination domain
     */
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external notDenylistedCallers {
        require(hookData.length > 0, "Hook data is empty");

        _depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            hookData
        );
    }

    /**
     * @notice Handles an incoming finalized message received by the local MessageTransmitter,
     * and takes the appropriate action. For a burn message, mints the
     * associated token to the requested recipient on the local domain.
     * @dev Validates the local sender is the local MessageTransmitter, and the
     * remote sender is a registered remote TokenMessenger for `remoteDomain`.
     * @param remoteDomain The domain where the message originated from.
     * @param sender The sender of the message (remote TokenMessenger).
     * @param messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveFinalizedMessage(
        uint32 remoteDomain,
        bytes32 sender,
        uint32,
        bytes calldata messageBody
    )
        external
        override
        onlyLocalMessageTransmitter
        onlyRemoteTokenMessenger(remoteDomain, sender)
        returns (bool)
    {
        // Validate finalized message
        bytes29 _msg = messageBody.ref(0);
        (
            address _mintRecipient,
            bytes32 _burnToken,
            uint256 _amount
        ) = _validateFinalizedMessage(_msg);

        _mintAndWithdraw(remoteDomain, _burnToken, _mintRecipient, _amount, 0);

        return true;
    }

    /**
     * @notice Handles an incoming unfinalized message received by the local MessageTransmitter,
     * and takes the appropriate action. For a burn message, mints the
     * associated token to the requested recipient on the local domain, less fees.
     * Fees are separately minted to the currently set `feeRecipient` address.
     * @dev Validates the local sender is the local MessageTransmitter, and the
     * remote sender is a registered remote TokenMessenger for `remoteDomain`.
     * @dev Validates that `finalityThresholdExecuted` is at least 1000.
     * @param remoteDomain The domain where the message originated from.
     * @param sender The sender of the message (remote TokenMessenger).
     * @param messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveUnfinalizedMessage(
        uint32 remoteDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    )
        external
        override
        onlyLocalMessageTransmitter
        onlyRemoteTokenMessenger(remoteDomain, sender)
        returns (bool)
    {
        // Require minimum supported finality threshold
        require(
            finalityThresholdExecuted >= MINIMUM_SUPPORTED_FINALITY_THRESHOLD,
            "Unsupported finality threshold"
        );

        // Validate message
        bytes29 _msg = messageBody.ref(0);
        (
            address _mintRecipient,
            bytes32 _burnToken,
            uint256 _amount,
            uint256 _fee
        ) = _validateUnfinalizedMessage(_msg);

        _mintAndWithdraw(
            remoteDomain,
            _burnToken,
            _mintRecipient,
            _amount - _fee,
            _fee
        );

        return true;
    }

    // ============ Internal Utils ============
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @param _amount amount of tokens to burn (must be non-zero)
     * @param _destinationDomain destination domain
     * @param _mintRecipient address of mint recipient on destination domain
     * @param _burnToken address of contract to burn deposited tokens, on local domain
     * @param _destinationCaller caller on the destination domain, as bytes32
     * @param _maxFee maximum fee to pay on destination chain
     * @param _hookData optional hook data for execution on destination chain
     */
    function _depositForBurn(
        uint256 _amount,
        uint32 _destinationDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) internal {
        require(_amount > 0, "Amount must be nonzero");
        require(_mintRecipient != bytes32(0), "Mint recipient must be nonzero");
        require(_maxFee < _amount, "Max fee must be less than amount");

        bytes32 _destinationTokenMessenger = _getRemoteTokenMessenger(
            _destinationDomain
        );

        // Deposit and burn tokens
        _depositAndBurn(_burnToken, msg.sender, _amount);

        // Format message body
        bytes memory _burnMessage = BurnMessageV2._formatMessageForRelay(
            messageBodyVersion,
            AddressUtils.addressToBytes32(_burnToken),
            _mintRecipient,
            _amount,
            AddressUtils.addressToBytes32(msg.sender),
            _maxFee,
            _hookData
        );

        // Send message
        IRelayerV2(localMessageTransmitter).sendMessage(
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
            _hookData
        );
    }

    /**
     * @notice Validates a finalized BurnMessage and unpacks relevant message fields.
     * @dev Reverts if the BurnMessage is malformed
     * @dev Reverts if the BurnMessage version isn't supported
     * @param _msg Finalized message
     * @return _mintRecipient The recipient of the mint, as bytes32
     * @return _burnToken The token address burned on the source chain
     * @return _amount The amount of burnToken burned
     */
    function _validateFinalizedMessage(
        bytes29 _msg
    )
        internal
        view
        returns (address _mintRecipient, bytes32 _burnToken, uint256 _amount)
    {
        _msg._validateBurnMessageFormat();
        require(
            _msg._getVersion() == messageBodyVersion,
            "Invalid message body version"
        );

        return (
            AddressUtils.bytes32ToAddress(_msg._getMintRecipient()),
            _msg._getBurnToken(),
            _msg._getAmount()
        );
    }

    /**
     * @notice Validates a finalized BurnMessage and unpacks relevant message fields.
     * @dev Reverts if the BurnMessage is malformed
     * @dev Reverts if the BurnMessage version isn't supported
     * @dev Reverts if the message is expired
     * @dev Reverts if the fee executed exceeds the amount
     * @param _msg Finalized message
     * @return _mintRecipient The recipient of the mint, as bytes32
     * @return _burnToken The token address burned on the source chain
     * @return _amount The amount of burnToken burned
     */
    function _validateUnfinalizedMessage(
        bytes29 _msg
    )
        internal
        view
        returns (
            address _mintRecipient,
            bytes32 _burnToken,
            uint256 _amount,
            uint256 _fee
        )
    {
        (_mintRecipient, _burnToken, _amount) = _validateFinalizedMessage(_msg);

        // Enforce message expiration
        uint256 _expirationBlock = _msg._getExpirationBlock();
        require(
            _expirationBlock == 0 || _expirationBlock > block.number,
            "Message expired and must be re-signed"
        );

        // Validate fee
        _fee = _msg._getFeeExecuted();
        require(_fee == 0 || _fee < _amount, "Fee equals or exceeds amount");
    }
}
