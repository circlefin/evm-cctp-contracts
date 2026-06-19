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

/**
 * @title ITokenMessengerV2
 * @notice Interface for the v2 TokenMessenger, exposing the external entrypoints,
 * events, and read-only accessors that integrators rely on to deposit/burn tokens
 * on a source domain for minting on a destination domain.
 * @dev Mirrors the external surface of {TokenMessengerV2}. The selectors and event
 * topics match the deployed contract, so this interface may be used to type calls
 * against, and to decode logs from, any v2 TokenMessenger deployment.
 */
interface ITokenMessengerV2 {
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

    /**
     * @notice Emitted when tokens are minted
     * @param mintRecipient recipient address of minted tokens
     * @param amount amount of minted tokens received by `mintRecipient`
     * @param mintToken contract address of minted token
     * @param feeCollected fee collected for mint
     */
    event MintAndWithdraw(
        address indexed mintRecipient,
        uint256 amount,
        address indexed mintToken,
        uint256 feeCollected
    );

    // ============ External Functions ============
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken token to burn `amount` of, on local domain
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
    ) external;

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain, as bytes32
     * @param burnToken token to burn `amount` of, on local domain
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
    ) external;

    /**
     * @notice Returns the minimum fee for a given amount
     * @param amount The amount for which to calculate the minimum fee
     * @return The minimum fee for the given amount
     */
    function getMinFeeAmount(uint256 amount) external view returns (uint256);

    // ============ Views ============
    /// @notice Version of message body format emitted by this TokenMessenger.
    function messageBodyVersion() external view returns (uint32);

    /// @notice Local TokenMinter authorized to mint/burn for this TokenMessenger.
    function localMinter() external view returns (address);

    /// @notice Local MessageTransmitter used to send/receive messages.
    function localMessageTransmitter() external view returns (address);

    /// @notice Registered remote TokenMessenger for a given remote `domain`, as bytes32.
    function remoteTokenMessengers(
        uint32 domain
    ) external view returns (bytes32);

    /// @notice Address that receives collected fees.
    function feeRecipient() external view returns (address);

    /// @notice Minimum fee for all transfers, in 1/1000 basis points.
    function minFee() external view returns (uint256);

    /// @notice Multiplier supporting 1/1000 basis point precision for `minFee`.
    function MIN_FEE_MULTIPLIER() external view returns (uint256);
}
