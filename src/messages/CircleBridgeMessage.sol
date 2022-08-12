/* SPDX-License-Identifier: UNLICENSED
 *
 * Copyright (c) 2022, Circle Internet Financial Trading Company Limited.
 * All rights reserved.
 *
 * Circle Internet Financial Trading Company Limited CONFIDENTIAL
 *
 * This file includes unpublished proprietary source code of Circle Internet
 * Financial Trading Company Limited, Inc. The copyright notice above does not
 * evidence any actual or intended publication of such source code. Disclosure
 * of this source code or any related proprietary information is strictly
 * prohibited without the express written permission of Circle Internet Financial
 * Trading Company Limited.
 */
pragma solidity ^0.7.6;

import "@memview-sol/contracts/TypedMemView.sol";

/**
 * @title CircleBridgeMessage Library
 * @notice Library for formatted messages used by CircleBridge contracts.
 * @dev DepositForBurn message format:
 * Field                 Bytes      Type       Index
 * type                  1          uint8      0
 * burnToken             32         bytes32    1
 * mintRecipient         32         bytes32    33
 * amount                32         uint256    65
 **/
library CircleBridgeMessage {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    uint32 private constant TYPE_INDEX = 0;
    uint8 private constant TYPE_LEN = 1;
    uint32 private constant BURN_TOKEN_INDEX = 1;
    uint8 private constant BURN_TOKEN_LEN = 32;
    uint32 private constant MINT_RECIPIENT_INDEX = 33;
    uint8 private constant MINT_RECIPIENT_LEN = 32;
    uint32 private constant AMOUNT_INDEX = 65;
    uint8 private constant AMOUNT_LEN = 32;

    // @notice Do not rewrite type ordering. Type informs the message structure.
    // Initially, only valid type is DepositForBurn.
    enum Types {
        // 0
        DepositForBurn
    }

    /**
     * @notice Formats DepositForBurn message
     * @param _burnToken The burn token address on source domain as bytes32
     * @param _mintRecipient The mint recipient address as bytes32
     * @param _amount The burn amount
     * @return DepositForBurn formatted message.
     */
    function formatDepositForBurn(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                Types.DepositForBurn,
                _burnToken,
                _mintRecipient,
                _amount
            );
    }

    /**
     * @notice Retrieves the burnToken from a DepositForBurn CircleBridgeMessage
     * @param _message The message
     * @return sourceToken address as bytes32
     */
    function getBurnToken(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(BURN_TOKEN_INDEX, BURN_TOKEN_LEN);
    }

    /**
     * @notice Retrieves the mintRecipient from a DepositForBurn CircleBridgeMessage
     * @param _message The message
     * @return mintRecipient
     */
    function getMintRecipient(bytes29 _message)
        internal
        pure
        returns (bytes32)
    {
        return _message.index(MINT_RECIPIENT_INDEX, MINT_RECIPIENT_LEN);
    }

    /**
     * @notice Retrieves the amount from a DepositForBurn CircleBridgeMessage
     * @param _message The message
     * @return amount
     */
    function getAmount(bytes29 _message) internal pure returns (uint256) {
        return _message.indexUint(AMOUNT_INDEX, AMOUNT_LEN);
    }
}
