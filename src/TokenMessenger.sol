/*
 * Copyright (c) 2022, Circle Internet Financial Limited.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

import "./interfaces/IMessageHandler.sol";
import "./interfaces/ITokenMinter.sol";
import "./interfaces/IMintBurnToken.sol";
import "./interfaces/IMessageTransmitter.sol";
import "./messages/BurnMessage.sol";
import "./messages/Message.sol";
import "./roles/Rescuable.sol";

/**
 * @title TokenMessenger
 * @notice Sends messages and receives messages to/from MessageTransmitters
 * and to/from TokenMinters
 */
contract TokenMessenger is IMessageHandler, Rescuable {
    // ============ Events ============
    /**
     * @notice Emitted when a DepositForBurn message is sent
     * @param nonce unique nonce reserved by message
     * @param burnToken address of token burnt on source domain
     * @param amount deposit amount
     * @param depositor address where deposit is transferred from
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param destinationDomain destination domain
     * @param destinationTokenMessenger address of TokenMessenger on destination domain as bytes32
     * @param destinationCaller authorized caller as bytes32 of receiveMessage() on destination domain, if not equal to bytes32(0).
     * If equal to bytes32(0), any address can call receiveMessage().
     */
    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    /**
     * @notice Emitted when tokens are minted
     * @param mintRecipient recipient address of minted tokens
     * @param amount amount of minted tokens
     * @param mintToken contract address of minted token
     */
    event MintAndWithdraw(
        address indexed mintRecipient,
        uint256 amount,
        address indexed mintToken
    );

    /**
     * @notice Emitted when a remote TokenMessenger is added
     * @param domain remote domain
     * @param tokenMessenger TokenMessenger on remote domain
     */
    event RemoteTokenMessengerAdded(uint32 domain, bytes32 tokenMessenger);

    /**
     * @notice Emitted when a remote TokenMessenger is removed
     * @param domain remote domain
     * @param tokenMessenger TokenMessenger on remote domain
     */
    event RemoteTokenMessengerRemoved(uint32 domain, bytes32 tokenMessenger);

    /**
     * @notice Emitted when the local minter is added
     * @param localMinter address of local minter
     * @notice Emitted when the local minter is added
     */
    event LocalMinterAdded(address localMinter);

    /**
     * @notice Emitted when the local minter is removed
     * @param localMinter address of local minter
     * @notice Emitted when the local minter is removed
     */
    event LocalMinterRemoved(address localMinter);

    // ============ Libraries ============
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessage for bytes29;
    using Message for bytes29;

    // ============ State Variables ============
    // Local Message Transmitter responsible for sending and receiving messages to/from remote domains
    IMessageTransmitter public immutable localMessageTransmitter;

    // Version of message body format
    uint32 public immutable messageBodyVersion;

    // Minter responsible for minting and burning tokens on the local domain
    ITokenMinter public localMinter;

    // Valid TokenMessengers on remote domains
    mapping(uint32 => bytes32) public remoteTokenMessengers;

    // ============ Modifiers ============
    /**
     * @notice Only accept messages from a registered TokenMessenger contract on given remote domain
     * @param domain The remote domain
     * @param tokenMessenger The address of the TokenMessenger contract for the given remote domain
     */
    modifier onlyRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger) {
        require(
            _isRemoteTokenMessenger(domain, tokenMessenger),
            "Remote TokenMessenger unsupported"
        );
        _;
    }

    /**
     * @notice Only accept messages from the registered message transmitter on local domain
     */
    modifier onlyLocalMessageTransmitter() {
        // Caller must be the registered message transmitter for this domain
        require(_isLocalMessageTransmitter(), "Invalid message transmitter");
        _;
    }

    // ============ Constructor ============
    /**
     * @param _messageTransmitter Message transmitter address
     * @param _messageBodyVersion Message body version
     */
    constructor(address _messageTransmitter, uint32 _messageBodyVersion) {
        require(
            _messageTransmitter != address(0),
            "MessageTransmitter not set"
        );
        localMessageTransmitter = IMessageTransmitter(_messageTransmitter);
        messageBodyVersion = _messageBodyVersion;
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
     * - MessageTransmitter returns false or reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @return _nonce unique nonce reserved by message
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 _nonce) {
        return
            _depositForBurn(
                amount,
                destinationDomain,
                mintRecipient,
                burnToken,
                // (bytes32(0) here indicates that any address can call receiveMessage()
                // on the destination domain, triggering mint to specified `mintRecipient`)
                bytes32(0)
            );
    }

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain. The mint
     * on the destination domain must be called by `destinationCaller`.
     * WARNING: if the `destinationCaller` does not represent a valid address as bytes32, then it will not be possible
     * to broadcast the message on the destination domain. This is an advanced feature, and the standard
     * depositForBurn() should be preferred for use cases where a specific destination caller is not required.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - given destinationCaller is zero address
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - MessageTransmitter returns false or reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @param destinationCaller caller on the destination domain, as bytes32
     * @return nonce unique nonce reserved by message
     */
    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce) {
        // Destination caller must be nonzero. To allow any destination caller, use depositForBurn().
        require(destinationCaller != bytes32(0), "Invalid destination caller");

        return
            _depositForBurn(
                amount,
                destinationDomain,
                mintRecipient,
                burnToken,
                destinationCaller
            );
    }

    /**
     * @notice Replace a BurnMessage to change the mint recipient and/or
     * destination caller. Allows the sender of a previous BurnMessage
     * (created by depositForBurn or depositForBurnWithCaller)
     * to send a new BurnMessage to replace the original.
     * The new BurnMessage will reuse the amount and burn token of the original,
     * without requiring a new deposit.
     * @dev The new message will reuse the original message's nonce. For a
     * given nonce, all replacement message(s) and the original message are
     * valid to broadcast on the destination domain, until the first message
     * at the nonce confirms, at which point all others are invalidated.
     * Note: The msg.sender of the replaced message must be the same as the
     * msg.sender of the original message.
     * @param originalMessage original message bytes (to replace)
     * @param originalAttestation original attestation bytes
     * @param newDestinationCaller the new destination caller, which may be the
     * same as the original destination caller, a new destination caller, or an empty
     * destination caller (bytes32(0), indicating that any destination caller is valid.)
     * @param newMintRecipient the new mint recipient, which may be the same as the
     * original mint recipient, or different.
     */
    function replaceDepositForBurn(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes32 newDestinationCaller,
        bytes32 newMintRecipient
    ) external {
        bytes29 _originalMsg = originalMessage.ref(0);
        _originalMsg._validateMessageFormat();
        bytes29 _originalMsgBody = _originalMsg._messageBody();
        _originalMsgBody._validateBurnMessageFormat();

        bytes32 _originalMsgSender = _originalMsgBody._getMessageSender();
        // _originalMsgSender must match msg.sender of original message
        require(
            msg.sender == Message.bytes32ToAddress(_originalMsgSender),
            "Invalid sender for message"
        );
        require(
            newMintRecipient != bytes32(0),
            "Mint recipient must be nonzero"
        );

        bytes32 _burnToken = _originalMsgBody._getBurnToken();
        uint256 _amount = _originalMsgBody._getAmount();

        bytes memory _newMessageBody = BurnMessage._formatMessage(
            messageBodyVersion,
            _burnToken,
            newMintRecipient,
            _amount,
            _originalMsgSender
        );

        localMessageTransmitter.replaceMessage(
            originalMessage,
            originalAttestation,
            _newMessageBody,
            newDestinationCaller
        );

        emit DepositForBurn(
            _originalMsg._nonce(),
            Message.bytes32ToAddress(_burnToken),
            _amount,
            msg.sender,
            newMintRecipient,
            _originalMsg._destinationDomain(),
            _originalMsg._recipient(),
            newDestinationCaller
        );
    }

    /**
     * @notice Handles an incoming message received by the local MessageTransmitter,
     * and takes the appropriate action. For a burn message, mints the
     * associated token to the requested recipient on the local domain.
     * @dev Validates the local sender is the local MessageTransmitter, and the
     * remote sender is a registered remote TokenMessenger for `remoteDomain`.
     * @param remoteDomain The domain where the message originated from.
     * @param sender The sender of the message (remote TokenMessenger).
     * @param messageBody The message body bytes.
     * @return success Bool, true if successful.
     */
    function handleReceiveMessage(
        uint32 remoteDomain,
        bytes32 sender,
        bytes calldata messageBody
    )
        external
        override
        onlyLocalMessageTransmitter
        onlyRemoteTokenMessenger(remoteDomain, sender)
        returns (bool)
    {
        bytes29 _msg = messageBody.ref(0);
        _msg._validateBurnMessageFormat();
        require(
            _msg._getVersion() == messageBodyVersion,
            "Invalid message body version"
        );

        bytes32 _mintRecipient = _msg._getMintRecipient();
        bytes32 _burnToken = _msg._getBurnToken();
        uint256 _amount = _msg._getAmount();

        ITokenMinter _localMinter = _getLocalMinter();

        _mintAndWithdraw(
            address(_localMinter),
            remoteDomain,
            _burnToken,
            Message.bytes32ToAddress(_mintRecipient),
            _amount
        );

        return true;
    }

    /**
     * @notice Add the TokenMessenger for a remote domain.
     * @dev Reverts if there is already a TokenMessenger set for domain.
     * @param domain Domain of remote TokenMessenger.
     * @param tokenMessenger Address of remote TokenMessenger as bytes32.
     */
    function addRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger)
        external
        onlyOwner
    {
        require(tokenMessenger != bytes32(0), "bytes32(0) not allowed");

        require(
            remoteTokenMessengers[domain] == bytes32(0),
            "TokenMessenger already set"
        );

        remoteTokenMessengers[domain] = tokenMessenger;
        emit RemoteTokenMessengerAdded(domain, tokenMessenger);
    }

    /**
     * @notice Remove the TokenMessenger for a remote domain.
     * @dev Reverts if there is no TokenMessenger set for `domain`.
     * @param domain Domain of remote TokenMessenger
     */
    function removeRemoteTokenMessenger(uint32 domain) external onlyOwner {
        // No TokenMessenger set for given remote domain.
        require(
            remoteTokenMessengers[domain] != bytes32(0),
            "No TokenMessenger set"
        );

        bytes32 _removedTokenMessenger = remoteTokenMessengers[domain];
        delete remoteTokenMessengers[domain];
        emit RemoteTokenMessengerRemoved(domain, _removedTokenMessenger);
    }

    /**
     * @notice Add minter for the local domain.
     * @dev Reverts if a minter is already set for the local domain.
     * @param newLocalMinter The address of the minter on the local domain.
     */
    function addLocalMinter(address newLocalMinter) external onlyOwner {
        require(newLocalMinter != address(0), "Zero address not allowed");

        require(
            address(localMinter) == address(0),
            "Local minter is already set."
        );

        localMinter = ITokenMinter(newLocalMinter);

        emit LocalMinterAdded(newLocalMinter);
    }

    /**
     * @notice Remove the minter for the local domain.
     * @dev Reverts if the minter of the local domain is not set.
     */
    function removeLocalMinter() external onlyOwner {
        address _localMinterAddress = address(localMinter);
        require(_localMinterAddress != address(0), "No local minter is set.");

        delete localMinter;
        emit LocalMinterRemoved(_localMinterAddress);
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
     * @return nonce unique nonce reserved by message
     */
    function _depositForBurn(
        uint256 _amount,
        uint32 _destinationDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller
    ) internal returns (uint64 nonce) {
        require(_amount > 0, "Amount must be nonzero");
        require(_mintRecipient != bytes32(0), "Mint recipient must be nonzero");

        bytes32 _destinationTokenMessenger = _getRemoteTokenMessenger(
            _destinationDomain
        );

        ITokenMinter _localMinter = _getLocalMinter();
        IMintBurnToken _mintBurnToken = IMintBurnToken(_burnToken);
        require(
            _mintBurnToken.transferFrom(
                msg.sender,
                address(_localMinter),
                _amount
            ),
            "Transfer operation failed"
        );
        _localMinter.burn(_burnToken, _amount);

        // Format message body
        bytes memory _burnMessage = BurnMessage._formatMessage(
            messageBodyVersion,
            Message.addressToBytes32(_burnToken),
            _mintRecipient,
            _amount,
            Message.addressToBytes32(msg.sender)
        );

        uint64 _nonceReserved = _sendDepositForBurnMessage(
            _destinationDomain,
            _destinationTokenMessenger,
            _destinationCaller,
            _burnMessage
        );

        emit DepositForBurn(
            _nonceReserved,
            _burnToken,
            _amount,
            msg.sender,
            _mintRecipient,
            _destinationDomain,
            _destinationTokenMessenger,
            _destinationCaller
        );

        return _nonceReserved;
    }

    /**
     * @notice Sends a BurnMessage through the local message transmitter
     * @dev calls local message transmitter's sendMessage() function if `_destinationCaller` == bytes32(0),
     * or else calls sendMessageWithCaller().
     * @param _destinationDomain destination domain
     * @param _destinationTokenMessenger address of registered TokenMessenger contract on destination domain, as bytes32
     * @param _destinationCaller caller on the destination domain, as bytes32. If `_destinationCaller` == bytes32(0),
     * any address can call receiveMessage() on destination domain.
     * @param _burnMessage formatted BurnMessage bytes (message body)
     * @return nonce unique nonce reserved by message
     */
    function _sendDepositForBurnMessage(
        uint32 _destinationDomain,
        bytes32 _destinationTokenMessenger,
        bytes32 _destinationCaller,
        bytes memory _burnMessage
    ) internal returns (uint64 nonce) {
        if (_destinationCaller == bytes32(0)) {
            return
                localMessageTransmitter.sendMessage(
                    _destinationDomain,
                    _destinationTokenMessenger,
                    _burnMessage
                );
        } else {
            return
                localMessageTransmitter.sendMessageWithCaller(
                    _destinationDomain,
                    _destinationTokenMessenger,
                    _destinationCaller,
                    _burnMessage
                );
        }
    }

    /**
     * @notice Mints tokens to a recipient
     * @param _tokenMinter address of TokenMinter contract
     * @param _remoteDomain domain where burned tokens originate from
     * @param _burnToken address of token burned
     * @param _mintRecipient recipient address of minted tokens
     * @param _amount amount of minted tokens
     */
    function _mintAndWithdraw(
        address _tokenMinter,
        uint32 _remoteDomain,
        bytes32 _burnToken,
        address _mintRecipient,
        uint256 _amount
    ) internal {
        ITokenMinter _minter = ITokenMinter(_tokenMinter);
        address _mintToken = _minter.mint(
            _remoteDomain,
            _burnToken,
            _mintRecipient,
            _amount
        );

        emit MintAndWithdraw(_mintRecipient, _amount, _mintToken);
    }

    /**
     * @notice return the remote TokenMessenger for the given `_domain` if one exists, else revert.
     * @param _domain The domain for which to get the remote TokenMessenger
     * @return _tokenMessenger The address of the TokenMessenger on `_domain` as bytes32
     */
    function _getRemoteTokenMessenger(uint32 _domain)
        internal
        view
        returns (bytes32)
    {
        bytes32 _tokenMessenger = remoteTokenMessengers[_domain];
        require(_tokenMessenger != bytes32(0), "No TokenMessenger for domain");
        return _tokenMessenger;
    }

    /**
     * @notice return the local minter address if it is set, else revert.
     * @return local minter as ITokenMinter.
     */
    function _getLocalMinter() internal view returns (ITokenMinter) {
        require(address(localMinter) != address(0), "Local minter is not set");
        return localMinter;
    }

    /**
     * @notice Return true if the given remote domain and TokenMessenger is registered
     * on this TokenMessenger.
     * @param _domain The remote domain of the message.
     * @param _tokenMessenger The address of the TokenMessenger on remote domain.
     * @return true if a remote TokenMessenger is registered for `_domain` and `_tokenMessenger`,
     * on this TokenMessenger.
     */
    function _isRemoteTokenMessenger(uint32 _domain, bytes32 _tokenMessenger)
        internal
        view
        returns (bool)
    {
        return
            _tokenMessenger != bytes32(0) &&
            remoteTokenMessengers[_domain] == _tokenMessenger;
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
