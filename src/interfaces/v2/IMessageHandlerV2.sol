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

/**
 * @title IMessageHandlerV2
 * @notice Handles messages on destination domain forwarded from
 * an IReceiverV2
 */
interface IMessageHandlerV2 {
    /**
     * @notice handles an incoming finalized message from a Receiver
     * @dev Finalized messages have finality threshold values greater than or equal to 2000
     * @param sourceDomain the source domain of the message
     * @param sender the sender of the message
     * @param finalityThresholdExecuted the finality threshold at which the message was attested to
     * @param messageBody The message raw bytes
     * @return success bool, true if successful
     */
    function handleReceiveFinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool);

    /**
     * @notice handles an incoming unfinalized message from a Receiver
     * @dev Unfinalized messages have finality threshold values less than 2000
     * @param sourceDomain the source domain of the message
     * @param sender the sender of the message
     * @param finalityThresholdExecuted the (sub)finality threshold at which the message was attested to
     * @param messageBody The message raw bytes
     * @return success bool, true if successful
     */
    function handleReceiveUnfinalizedMessage(
        uint32 sourceDomain,
        bytes32 sender,
        uint32 finalityThresholdExecuted,
        bytes calldata messageBody
    ) external returns (bool);
}
