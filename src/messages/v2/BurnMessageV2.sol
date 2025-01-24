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

import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {BurnMessage} from "../BurnMessage.sol";

/**
 * @title BurnMessageV2 Library
 * @notice Library for formatted V2 BurnMessages used by TokenMessengerV2.
 * @dev BurnMessageV2 format:
 * Field                 Bytes      Type       Index
 * version               4          uint32     0
 * burnToken             32         bytes32    4
 * mintRecipient         32         bytes32    36
 * amount                32         uint256    68
 * messageSender         32         bytes32    100
 * maxFee                32         uint256    132
 * feeExecuted           32         uint256    164
 * expirationBlock       32         uint256    196
 * hookData              dynamic    bytes      228
 * @dev Additions from v1:
 * - maxFee
 * - feeExecuted
 * - expirationBlock
 * - hookData
 **/
library BurnMessageV2 {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessage for bytes29;

    // Field indices
    uint8 private constant MAX_FEE_INDEX = 132;
    uint8 private constant FEE_EXECUTED_INDEX = 164;
    uint8 private constant EXPIRATION_BLOCK_INDEX = 196;
    uint8 private constant HOOK_DATA_INDEX = 228;

    uint256 private constant EMPTY_FEE_EXECUTED = 0;
    uint256 private constant EMPTY_EXPIRATION_BLOCK = 0;

    /**
     * @notice Formats a V2 burn message
     * @param _version The message body version
     * @param _burnToken The burn token address on the source domain, as bytes32
     * @param _mintRecipient The mint recipient address as bytes32
     * @param _amount The burn amount
     * @param _messageSender The message sender
     * @param _maxFee The maximum fee to be paid on destination domain
     * @param _hookData Optional hook data for processing on the destination domain
     * @return Formatted message bytes.
     */
    function _formatMessageForRelay(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _messageSender,
        uint256 _maxFee,
        bytes calldata _hookData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _version,
                _burnToken,
                _mintRecipient,
                _amount,
                _messageSender,
                _maxFee,
                EMPTY_FEE_EXECUTED,
                EMPTY_EXPIRATION_BLOCK,
                _hookData
            );
    }

    // @notice Returns _message's version field
    function _getVersion(bytes29 _message) internal pure returns (uint32) {
        return _message._getVersion();
    }

    // @notice Returns _message's burnToken field
    function _getBurnToken(bytes29 _message) internal pure returns (bytes32) {
        return _message._getBurnToken();
    }

    // @notice Returns _message's mintRecipient field
    function _getMintRecipient(
        bytes29 _message
    ) internal pure returns (bytes32) {
        return _message._getMintRecipient();
    }

    // @notice Returns _message's amount field
    function _getAmount(bytes29 _message) internal pure returns (uint256) {
        return _message._getAmount();
    }

    // @notice Returns _message's messageSender field
    function _getMessageSender(
        bytes29 _message
    ) internal pure returns (bytes32) {
        return _message._getMessageSender();
    }

    // @notice Returns _message's maxFee field
    function _getMaxFee(bytes29 _message) internal pure returns (uint256) {
        return _message.indexUint(MAX_FEE_INDEX, 32);
    }

    // @notice Returns _message's feeExecuted field
    function _getFeeExecuted(bytes29 _message) internal pure returns (uint256) {
        return _message.indexUint(FEE_EXECUTED_INDEX, 32);
    }

    // @notice Returns _message's expirationBlock field
    function _getExpirationBlock(
        bytes29 _message
    ) internal pure returns (uint256) {
        return _message.indexUint(EXPIRATION_BLOCK_INDEX, 32);
    }

    // @notice Returns _message's hookData field
    function _getHookData(bytes29 _message) internal pure returns (bytes29) {
        return
            _message.slice(
                HOOK_DATA_INDEX,
                _message.len() - HOOK_DATA_INDEX,
                0
            );
    }

    /**
     * @notice Reverts if burn message is malformed or invalid length
     * @param _message The burn message as bytes29
     */
    function _validateBurnMessageFormat(bytes29 _message) internal pure {
        require(_message.isValid(), "Malformed message");
        require(
            _message.len() >= HOOK_DATA_INDEX,
            "Invalid burn message: too short"
        );
    }
}
