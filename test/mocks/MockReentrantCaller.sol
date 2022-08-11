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

import "../../src/interfaces/IMessageDestinationHandler.sol";
import "../../src/interfaces/IReceiver.sol";
import "../../src/Message.sol";
import "../../lib/forge-std/src/console.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract MockReentrantCaller is IMessageDestinationHandler {
    bytes internal message;
    bytes internal signature;

    // ============ Constructor ============
    constructor() {}

    function setMessageAndSignature(
        bytes memory _message,
        bytes memory _signature
    ) external {
        message = _message;
        signature = _signature;
    }

    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 _sender,
        bytes memory _messageBody
    ) external override returns (bool) {
        // revert if _messageBody is 'revert', otherwise do nothing
        require(
            keccak256(_messageBody) != keccak256(bytes("revert")),
            "mock revert"
        );

        // if message body is 'reenter', call receiveMessage on caller
        if (keccak256(_messageBody) == keccak256(bytes("reenter"))) {
            bytes memory data = abi.encodeWithSelector(
                bytes4(keccak256("receiveMessage(bytes,bytes)")),
                message,
                signature
            );

            (bool success, bytes memory returnData) = msg.sender.call(data);

            // Check inner error message, and log separate error if it matches expectation.
            // (This allows tests to ensure that the error is logged from the re-entrant call.)
            if (stringEquals(_getRevertMsg(returnData), "Nonce already used")) {
                revert("Re-entrant call failed due to reused nonce");
            }
        }
    }

    // source: https://ethereum.stackexchange.com/a/83577
    function _getRevertMsg(bytes memory _returnData)
        internal
        pure
        returns (string memory)
    {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function stringEquals(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
