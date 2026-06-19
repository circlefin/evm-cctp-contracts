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
 * @notice Interface for depositing and burning tokens to be minted on a destination domain,
 * with support for fees, finality thresholds, and hook data.
 */
interface ITokenMessengerV2 {
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to
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
     * @notice Deposits and burns tokens from sender to be minted on destination domain,
     * with hook data appended for interpretation on the destination domain.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain, as bytes32
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to
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
     * @notice Handles an incoming finalized message received by the local MessageTransmitter.
     * @param remoteDomain The domain where the message originated from.
     * @param sender The sender of the message (remote TokenMessenger).
     * @param finalityThresholdExecuted The level of finality at which the message was attested to.
     * @param messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveFinalizedMessage(
        uint32 remoteDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success);

    /**
     * @notice Handles an incoming unfinalized message received by the local MessageTransmitter.
     * @param remoteDomain The domain where the message originated from.
     * @param sender The sender of the message (remote TokenMessenger).
     * @param finalityThresholdExecuted The level of finality at which the message was attested to.
     * @param messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveUnfinalizedMessage(
        uint32 remoteDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool success);

    /**
     * @notice Returns the minimum fee for a given amount.
     * @param amount The amount for which to calculate the minimum fee.
     * @return The minimum fee for the given amount.
     */
    function getMinFeeAmount(uint256 amount) external view returns (uint256);

    /**
     * @notice Add the TokenMessenger for a remote domain.
     * @param domain Domain of remote TokenMessenger.
     * @param tokenMessenger Address of remote TokenMessenger as bytes32.
     */
    function addRemoteTokenMessenger(
        uint32 domain,
        bytes32 tokenMessenger
    ) external;

    /**
     * @notice Remove the TokenMessenger for a remote domain.
     * @param domain Domain of remote TokenMessenger.
     */
    function removeRemoteTokenMessenger(uint32 domain) external;

    /**
     * @notice Add minter for the local domain.
     * @param newLocalMinter The address of the minter on the local domain.
     */
    function addLocalMinter(address newLocalMinter) external;

    /**
     * @notice Remove the minter for the local domain.
     */
    function removeLocalMinter() external;

    /**
     * @notice Sets the fee recipient address.
     * @param _feeRecipient Address of fee recipient.
     */
    function setFeeRecipient(address _feeRecipient) external;

    /**
     * @notice Sets the minimum fee controller address.
     * @param _minFeeController Address of minimum fee controller.
     */
    function setMinFeeController(address _minFeeController) external;

    /**
     * @notice Sets the minimum fee for all transfers in 1/1000 basis points.
     * @param _minFee Minimum fee.
     */
    function setMinFee(uint256 _minFee) external;

    /**
     * @notice Returns the current initialized version.
     */
    function initializedVersion() external view returns (uint64);
}
