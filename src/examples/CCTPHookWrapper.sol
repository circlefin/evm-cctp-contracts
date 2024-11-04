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

import {IReceiverV2} from "../interfaces/v2/IReceiverV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {MessageV2} from "../messages/v2/MessageV2.sol";
import {BurnMessageV2} from "../messages/v2/BurnMessageV2.sol";

/**
 * @title CCTPHookWrapper
 * @notice A sample wrapper around CCTP v2 that relays a message and
 * optionally executes the hook contained in the Burn Message.
 * @dev This is intended to only work with CCTP v2 message formats and interfaces.
 */
contract CCTPHookWrapper {
    // ============ State Variables ============
    // Address of the local message transmitter
    IReceiverV2 public immutable messageTransmitter;

    // The supported Message Format version
    uint32 public immutable supportedMessageVersion;

    // The supported Message Body version
    uint32 public immutable supportedMessageBodyVersion;

    // Byte-length of an address
    uint256 internal constant ADDRESS_BYTE_LENGTH = 20;

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // ============ Modifiers ============
    /**
     * @notice A modifier to enable access control
     * @dev Can be overridden to customize the behavior
     */
    modifier onlyAllowed() virtual {
        _;
    }

    // ============ Constructor ============
    /**
     * @param _messageTransmitter The address of the local message transmitter
     * @param _messageVersion The required CCTP message version. For CCTP v2, this is 1.
     * @param _messageBodyVersion The required message body (Burn Message) version. For CCTP v2, this is 1.
     */
    constructor(
        address _messageTransmitter,
        uint32 _messageVersion,
        uint32 _messageBodyVersion
    ) {
        require(
            _messageTransmitter != address(0),
            "Message transmitter is the zero address"
        );

        messageTransmitter = IReceiverV2(_messageTransmitter);
        supportedMessageVersion = _messageVersion;
        supportedMessageBodyVersion = _messageBodyVersion;
    }

    // ============ External Functions  ============
    /**
     * @notice Relays a burn message to a local message transmitter
     * and executes the hook, if present.
     *
     * @dev The hook data contained in the Burn Message is expected to follow this format:
     * Field                 Bytes      Type       Index
     * target                20         address    0
     * hookCallData          dynamic    bytes      20
     *
     * The hook handler will call the target address with the hookCallData, even if hookCallData
     * is zero-length. Additional data about the burn message is not passed in this call.
     *
     * WARNING: this implementation does NOT enforce atomicity in the hook call. If atomicity is
     * required, a new wrapper contract can be created, possibly by overriding this behavior in `_handleHook`,
     * or by introducing a different format for the hook data that includes more information about
     * the desired handling.
     *
     * WARNING: in a permissionless context, it is important not to view this wrapper implementation as a trusted
     * caller of a hook, as others can craft messages containing hooks that look identical, that are
     * similarly executed from this wrapper, either by setting this contract as the destination caller,
     * or by setting the destination caller to be bytes32(0). Alternate implementations may extract more information
     * from the burn message, such as the mintRecipient or the amount, to include in the hook call to allow recipients
     * to further filter their receiving actions.
     *
     * WARNING: re-entrant behavior is allowed in this implementation. Relay() can be overridden to disable this.
     *
     * @dev Reverts if the receiveMessage() call to the local message transmitter reverts, or returns false.
     * @param message The message to relay, as bytes
     * @param attestation The attestation corresponding to the message, as bytes
     * @return relaySuccess True if the call to the local message transmitter succeeded.
     * @return hookSuccess True if the call to the hook target succeeded. False if the hook call failed,
     * or if no hook was present.
     * @return hookReturnData The data returned from the call to the hook target. This will be empty
     * if there was no hook in the message.
     */
    function relay(
        bytes calldata message,
        bytes calldata attestation
    )
        external
        virtual
        onlyAllowed
        returns (
            bool relaySuccess,
            bool hookSuccess,
            bytes memory hookReturnData
        )
    {
        bytes29 _msg = message.ref(0);
        bytes29 _msgBody = MessageV2._getMessageBody(_msg);

        // Perform message validation
        _validateMessage(_msg, _msgBody);

        // Relay message
        require(
            messageTransmitter.receiveMessage(message, attestation),
            "Receive message failed"
        );

        relaySuccess = true;

        // Handle hook
        bytes29 _hookData = BurnMessageV2._getHookData(_msgBody);
        (hookSuccess, hookReturnData) = _handleHook(_hookData);
    }

    // ============ Internal Functions  ============
    /**
     * @notice Validates a message and its message body
     * @dev Can be overridden to customize the validation
     * @dev Reverts if the message format version or message body version
     * do not match the supported versions.
     */
    function _validateMessage(
        bytes29 _message,
        bytes29 _messageBody
    ) internal virtual {
        require(
            MessageV2._getVersion(_message) == supportedMessageVersion,
            "Invalid message version"
        );
        require(
            BurnMessageV2._getVersion(_messageBody) ==
                supportedMessageBodyVersion,
            "Invalid message body version"
        );
    }

    /**
     * @notice Handles hook data by executing a call to a target address
     * @dev Can be overridden to customize the execution behavior
     * @param _hookData The hook data contained in the Burn Message
     * @return _success True if the call to the encoded hook target succeeds
     * @return _returnData The data returned from the call to the hook target
     */
    function _handleHook(
        bytes29 _hookData
    ) internal virtual returns (bool _success, bytes memory _returnData) {
        uint256 _hookDataLength = _hookData.len();

        if (_hookDataLength >= ADDRESS_BYTE_LENGTH) {
            address _target = _hookData.indexAddress(0);
            bytes memory _hookCalldata = _hookData
                .postfix(_hookDataLength - ADDRESS_BYTE_LENGTH, 0)
                .clone();

            (_success, _returnData) = address(_target).call(_hookCalldata);
        }
    }
}
