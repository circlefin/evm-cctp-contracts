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

import "./interfaces/IMessageDestinationHandler.sol";
import "./Message.sol";
import "./interfaces/IRelayer.sol";
import "./interfaces/IMintBurnToken.sol";

/**
 * @title CircleBridge
 * @notice sends messages and receives messages to/from MessageTransmitter
 */
contract CircleBridge is IMessageDestinationHandler {
    // ============ Public Variables ============
    IRelayer public immutable relayer;
    mapping(address => bool) public supportedBurnTokens;

    /**
     * @notice Emitted when a deposit for burn is received on source domain
     * @param depositor address where deposit is transferred from
     * @param burnToken address of token burnt on source domain
     * @param amount deposit amount
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param destinationDomain destination domain
     * @param minter address of minter on destination domain as bytes32
     */
    event DepositForBurn(
        address depositor,
        address burnToken,
        uint256 amount,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 minter
    );

    /**
     * @notice Emitted when a supported burn token is added
     */
    event SupportedBurnTokenAdded(address burnToken);

    /**
     * @notice Emitted when a supported burn token is removed
     */
    event SupportedBurnTokenRemoved(address burnToken);

    // ============ Constructor ============
    /**
     * @param _relayer Message relayer address
     */
    constructor(address _relayer) {
        relayer = IRelayer(_relayer);
    }

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - message relayer returns false or reverts.
     * @param _amount amount of tokens to burn
     * @param _destinationDomain destination domain
     * @param _mintRecipient address of mint recipient on destination domain
     * @param _burnToken address of contract to burn deposited tokens, on source chain
     * @return success bool, true if successful
     */
    function depositForBurn(
        uint256 _amount,
        uint32 _destinationDomain,
        bytes32 _mintRecipient,
        address _burnToken
    ) external returns (bool success) {
        require(
            supportedBurnTokens[_burnToken],
            "Given burnToken is not supported"
        );

        IMintBurnToken mintBurnToken = IMintBurnToken(_burnToken);
        mintBurnToken.transferFrom(msg.sender, address(this), _amount);
        mintBurnToken.burn(_amount);

        // TODO [BRAAV-11739] serialize message body: {_mintRecipient, _amount}
        bytes memory _messageBody = bytes("foo");

        // TODO [BRAAV-11739] select minter (destination Circle Bridge address)
        // for destination domain from local mapping of (uint32 domain -> bytes32 minter)
        // TODO [BRAAV-11739] also validate minter is not default value, to ensure destination domain is valid
        bytes32 _minter = bytes32("bar");

        require(
            relayer.sendMessage(_destinationDomain, _minter, _messageBody),
            "Relayer sendMessage() returned false"
        );

        emit DepositForBurn(
            msg.sender,
            _burnToken,
            _amount,
            _mintRecipient,
            _destinationDomain,
            _minter
        );

        return true;
    }

    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 _sender,
        bytes memory _messageBody
    ) external override returns (bool) {
        // TODO stub
    }

    function addSupportedBurnToken(address _burnToken)
        external
    // TODO BRAAV-11741 onlyTokensManager
    {
        require(
            !supportedBurnTokens[_burnToken],
            "burnToken already supported"
        );
        supportedBurnTokens[_burnToken] = true;
        emit SupportedBurnTokenAdded(_burnToken);
    }

    function removeSupportedBurnToken(address _burnToken)
        external
    // TODO BRAAV-11741 onlyTokensManager
    {
        require(
            supportedBurnTokens[_burnToken],
            "burnToken already unsupported"
        );
        supportedBurnTokens[_burnToken] = false;
        emit SupportedBurnTokenRemoved(_burnToken);
    }
}
