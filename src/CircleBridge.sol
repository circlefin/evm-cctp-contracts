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
import "./interfaces/IMinter.sol";
import "./interfaces/IMintBurnToken.sol";
import "./interfaces/IMessageTransmitter.sol";
import "./messages/BurnMessage.sol";
import "./messages/Message.sol";
import "./roles/Rescuable.sol";

/**
 * @title CircleBridge
 * @notice Sends messages and receives messages to/from MessageTransmitters
 * and to/from CircleMinters
 */
contract CircleBridge is IMessageDestinationHandler, Rescuable {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessage for bytes29;

    // ============ Public Variables ============
    // Local Message Transmitter responsible for sending and receiving messages to/from remote domains
    IMessageTransmitter public immutable localMessageTransmitter;

    // Minter responsible for minting and burning tokens on the local domain
    IMinter public localMinter;

    // Valid CircleBridges on remote domains
    mapping(uint32 => bytes32) public remoteCircleBridges;

    // Version of message body format
    uint32 public messageBodyVersion;

    /**
     * @notice Emitted when a deposit for burn is received on local domain
     * @param depositor address where deposit is transferred from
     * @param burnToken address of token burnt on local domain
     * @param amount deposit amount
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param destinationDomain destination domain
     * @param destinationCircleBridge address of CircleBridge on destination domain as bytes32
     */
    event DepositForBurn(
        address depositor,
        address burnToken,
        uint256 amount,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationCircleBridge
    );

    /**
     * @notice Emitted when tokens are minted
     * @param _mintRecipient recipient address of minted tokens
     * @param _amount amount of minted tokens
     * @param _mintToken contract address of minted token
     */
    event MintAndWithdraw(
        address _mintRecipient,
        uint256 _amount,
        address _mintToken
    );

    /**
     * @notice Emitted when a remote CircleBridge is added
     * @param _domain remote domain
     * @param _circleBridge CircleBridge on remote domain
     */
    event RemoteCircleBridgeAdded(uint32 _domain, bytes32 _circleBridge);

    /**
     * @notice Emitted when a remote CircleBridge is removed
     * @param _domain remote domain
     * @param _circleBridge CircleBridge on remote domain
     */
    event RemoteCircleBridgeRemoved(uint32 _domain, bytes32 _circleBridge);

    /**
     * @notice Emitted when the local minter is added
     * @param _localMinter address of local minter
     * @notice Emitted when the local minter is added
     */
    event LocalMinterAdded(address _localMinter);

    /**
     * @notice Emitted when the local minter is removed
     * @param _localMinter address of local minter
     * @notice Emitted when the local minter is removed
     */
    event LocalMinterRemoved(address _localMinter);

    /**
     * @notice Only accept messages from a registered Circle Bridge contract on given remote domain
     * @param _domain The remote domain
     * @param _circleBridge The address of the Circle Bridge contract for the given remote domain
     */
    modifier onlyRemoteCircleBridge(uint32 _domain, bytes32 _circleBridge) {
        require(
            _isRemoteCircleBridge(_domain, _circleBridge),
            "Remote Circle Bridge is not supported"
        );
        _;
    }

    /**
     * @notice Only accept messages from the registered message transmitter on local domain
     */
    modifier onlyLocalMessageTransmitter() {
        require(
            _isLocalMessageTransmitter(),
            "Caller is not the registered message transmitter for this domain"
        );
        _;
    }

    // ============ Constructor ============
    /**
     * @param _messageTransmitter Message transmitter address
     * @param _messageBodyVersion Message body version
     */
    constructor(address _messageTransmitter, uint32 _messageBodyVersion) {
        localMessageTransmitter = IMessageTransmitter(_messageTransmitter);
        messageBodyVersion = _messageBodyVersion;
    }

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - given burnToken is not supported
     * - given destinationDomain has no CircleBridge registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - MessageTransmitter returns false or reverts.
     * @param _amount amount of tokens to burn
     * @param _destinationDomain destination domain
     * @param _mintRecipient address of mint recipient on destination domain
     * @param _burnToken address of contract to burn deposited tokens, on local domain
     * @return success bool, true if successful
     */
    function depositForBurn(
        uint256 _amount,
        uint32 _destinationDomain,
        bytes32 _mintRecipient,
        address _burnToken
    ) external returns (bool success) {
        bytes32 _destinationCircleBridge = _getRemoteCircleBridge(
            _destinationDomain
        );

        IMinter _localMinter = _getLocalMinter();

        IMintBurnToken mintBurnToken = IMintBurnToken(_burnToken);
        mintBurnToken.transferFrom(msg.sender, address(_localMinter), _amount);
        _localMinter.burn(_burnToken, _amount);

        // Format message body
        bytes memory _burnMessage = BurnMessage.formatMessage(
            messageBodyVersion,
            Message.addressToBytes32(_burnToken),
            _mintRecipient,
            _amount
        );

        require(
            localMessageTransmitter.sendMessage(
                _destinationDomain,
                _destinationCircleBridge,
                _burnMessage
            ),
            "MessageTransmitter sendMessage() returned false"
        );

        emit DepositForBurn(
            msg.sender,
            _burnToken,
            _amount,
            _mintRecipient,
            _destinationDomain,
            _destinationCircleBridge
        );

        return true;
    }

    /**
     * @notice Handles an incoming message received by the local MessageTransmitter,
     * and takes the appropriate action. For a burn message, mints the
     * associated token to the requested recipient on the local domain.
     * @dev Validates the local sender is the local MessageTransmitter, and the
     * remote sender is a registered remote CircleBridge for `_remoteDomain`.
     * @param _remoteDomain The domain where the message originated from.
     * @param _sender The sender of the message (remote CircleBridge).
     * @param _messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveMessage(
        uint32 _remoteDomain,
        bytes32 _sender,
        bytes memory _messageBody
    )
        external
        override
        onlyLocalMessageTransmitter
        onlyRemoteCircleBridge(_remoteDomain, _sender)
        returns (bool)
    {
        bytes29 _msg = _messageBody.ref(0);
        require(_msg.isValidBurnMessage(messageBodyVersion), "Invalid message");

        bytes32 _mintRecipient = _msg.getMintRecipient();
        bytes32 _burnToken = _msg.getBurnToken();
        uint256 _amount = _msg.getAmount();

        IMinter _localMinter = _getLocalMinter();
        address _mintToken = _localMinter.getEnabledLocalToken(
            _remoteDomain,
            _burnToken
        );

        _mintAndWithdraw(
            address(_localMinter),
            Message.bytes32ToAddress(_mintRecipient),
            _amount,
            _mintToken
        );

        return true;
    }

    /**
     * @notice Add the CircleBridge for a remote domain.
     * @dev Reverts if there is already a CircleBridge set for domain.
     * @param _domain Domain of remote CircleBridge.
     * @param _circleBridge Address of remote CircleBridge as bytes32.
     */
    function addRemoteCircleBridge(uint32 _domain, bytes32 _circleBridge)
        external
        onlyOwner
    {
        require(
            remoteCircleBridges[_domain] == bytes32(0),
            "CircleBridge already set for given remote domain."
        );

        remoteCircleBridges[_domain] = _circleBridge;
        emit RemoteCircleBridgeAdded(_domain, _circleBridge);
    }

    /**
     * @notice Remove the CircleBridge for a remote domain.
     * @dev Reverts if there is no CircleBridge set for `domain`.
     * @param _domain Domain of remote CircleBridge
     * @param _circleBridge Address of remote CircleBridge as bytes32
     */
    function removeRemoteCircleBridge(uint32 _domain, bytes32 _circleBridge)
        external
        onlyOwner
    {
        require(
            remoteCircleBridges[_domain] != bytes32(0),
            "No CircleBridge set for given remote domain."
        );

        remoteCircleBridges[_domain] = bytes32(0);
        emit RemoteCircleBridgeRemoved(_domain, _circleBridge);
    }

    /**
     * @notice Add minter for the local domain.
     * @dev Reverts if a minter is already set for the local domain.
     * @param _localMinter The address of the minter on the local domain.
     */
    function addLocalMinter(address _localMinter) external onlyOwner {
        require(
            address(localMinter) == address(0),
            "Local minter is already set."
        );

        localMinter = IMinter(_localMinter);

        emit LocalMinterAdded(_localMinter);
    }

    /**
     * @notice Remove the minter for the local domain.
     * @dev Reverts if the minter of the local domain is not set.
     */
    function removeLocalMinter() external onlyOwner {
        address localMinterAddress = address(localMinter);
        require(localMinterAddress != address(0), "No local minter is set.");

        localMinter = IMinter(address(0));
        emit LocalMinterRemoved(localMinterAddress);
    }

    /**
     * @notice Mints tokens to a recipient
     * @param _circleMinter address of Circle Minter contract
     * @param _mintRecipient recipient address of minted tokens
     * @param _amount amount of minted tokens
     * @param _mintToken contract address of minted token
     */
    function _mintAndWithdraw(
        address _circleMinter,
        address _mintRecipient,
        uint256 _amount,
        address _mintToken
    ) internal {
        IMinter _minter = IMinter(_circleMinter);
        _minter.mint(_mintToken, _mintRecipient, _amount);

        emit MintAndWithdraw(_mintRecipient, _amount, _mintToken);
    }

    /**
     * @notice return the remote CircleBridge for the given `_domain` if one exists, else revert.
     * @param _domain The domain for which to get the remote CircleBridge
     * @return _circleBridge The address of the CircleBridge on `_domain` as bytes32
     */
    function _getRemoteCircleBridge(uint32 _domain)
        internal
        view
        returns (bytes32)
    {
        bytes32 _circleBridge = remoteCircleBridges[_domain];
        require(
            _circleBridge != bytes32(0),
            "Remote CircleBridge does not exist for domain"
        );
        return _circleBridge;
    }

    /**
     * @notice return the local minter address if it is set, else revert.
     * @return local minter as IMinter.
     */
    function _getLocalMinter() internal view returns (IMinter) {
        require(address(localMinter) != address(0), "Local minter is not set");
        return localMinter;
    }

    /**
     * @notice Return true if the given remote domain and CircleBridge is registered
     * on this CircleBridge.
     * @param _domain The remote domain of the message.
     * @param _circleBridge The address of the CircleBridge on remote domain.
     * @return true if a remote CircleBridge is registered for `_domain` and `_circleBridge`,
     * on this CircleBridge.
     */
    function _isRemoteCircleBridge(uint32 _domain, bytes32 _circleBridge)
        internal
        view
        returns (bool)
    {
        return
            _circleBridge != bytes32(0) &&
            remoteCircleBridges[_domain] == _circleBridge;
    }

    /**
     * @notice Returns true if the message sender is the local registered MessageTransmitter
     * @return true if message sender is the registered local message transmitter
     */
    function _isLocalMessageTransmitter() internal view returns (bool) {
        return
            address(localMessageTransmitter) != address(0) &&
            msg.sender == address(localMessageTransmitter);
    }
}
