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

import "./interfaces/ITokenMinter.sol";
import "./interfaces/IMintBurnToken.sol";
import "./roles/Pausable.sol";
import "./roles/Rescuable.sol";
import "./roles/TokenController.sol";
import "./TokenMessenger.sol";

/**
 * @title TokenMinter
 * @notice Token Minter and Burner
 * @dev Maintains registry of local mintable tokens and corresponding tokens on remote domains.
 * This registry can be used by caller to determine which token on local domain to mint for a
 * burned token on a remote domain, and vice versa.
 * It is assumed that local and remote tokens are fungible at a constant 1:1 exchange rate.
 */
contract TokenMinter is ITokenMinter, TokenController, Pausable, Rescuable {
    // ============ Events ============
    /**
     * @notice Emitted when a local TokenMessenger is added
     * @param localTokenMessenger address of local TokenMessenger
     * @notice Emitted when a local TokenMessenger is added
     */
    event LocalTokenMessengerAdded(address localTokenMessenger);

    /**
     * @notice Emitted when a local TokenMessenger is removed
     * @param localTokenMessenger address of local TokenMessenger
     * @notice Emitted when a local TokenMessenger is removed
     */
    event LocalTokenMessengerRemoved(address localTokenMessenger);

    // ============ State Variables ============
    // Local TokenMessenger with permission to call mint and burn on this TokenMinter
    address public localTokenMessenger;

    // ============ Modifiers ============
    /**
     * @notice Only accept messages from the registered message transmitter on local domain
     */
    modifier onlyLocalTokenMessenger() {
        require(_isLocalTokenMessenger(), "Caller not local TokenMessenger");
        _;
    }

    // ============ Constructor ============
    /**
     * @param _tokenController Token controller address
     */
    constructor(address _tokenController) {
        _setTokenController(_tokenController);
    }

    // ============ External Functions  ============
    /**
     * @notice Mints `amount` of local tokens corresponding to the
     * given (`sourceDomain`, `burnToken`) pair, to `to` address.
     * @dev reverts if the (`sourceDomain`, `burnToken`) pair does not
     * map to a nonzero local token address. This mapping can be queried using
     * getLocalToken().
     * @param sourceDomain Source domain where `burnToken` was burned.
     * @param burnToken Burned token address as bytes32.
     * @param to Address to receive minted tokens, corresponding to `burnToken`,
     * on this domain.
     * @param amount Amount of tokens to mint. Must be less than or equal
     * to the minterAllowance of this TokenMinter for given `_mintToken`.
     * @return mintToken token minted.
     */
    function mint(
        uint32 sourceDomain,
        bytes32 burnToken,
        address to,
        uint256 amount
    )
        external
        override
        whenNotPaused
        onlyLocalTokenMessenger
        returns (address mintToken)
    {
        address _mintToken = _getLocalToken(sourceDomain, burnToken);
        require(_mintToken != address(0), "Mint token not supported");
        IMintBurnToken _token = IMintBurnToken(_mintToken);

        require(_token.mint(to, amount), "Mint operation failed");
        return _mintToken;
    }

    /**
     * @notice Burn tokens owned by this TokenMinter.
     * @param burnToken burnable token address.
     * @param burnAmount amount of tokens to burn. Must be
     * > 0, and <= maximum burn amount per message.
     */
    function burn(address burnToken, uint256 burnAmount)
        external
        override
        whenNotPaused
        onlyLocalTokenMessenger
        onlyWithinBurnLimit(burnToken, burnAmount)
    {
        IMintBurnToken _token = IMintBurnToken(burnToken);
        _token.burn(burnAmount);
    }

    /**
     * @notice Add TokenMessenger for the local domain. Only this TokenMessenger
     * has permission to call mint() and burn() on this TokenMinter.
     * @dev Reverts if a TokenMessenger is already set for the local domain.
     * @param newLocalTokenMessenger The address of the new TokenMessenger on the local domain.
     */
    function addLocalTokenMessenger(address newLocalTokenMessenger)
        external
        onlyOwner
    {
        require(
            newLocalTokenMessenger != address(0),
            "Invalid TokenMessenger address"
        );

        require(
            localTokenMessenger == address(0),
            "Local TokenMessenger already set"
        );

        localTokenMessenger = newLocalTokenMessenger;

        emit LocalTokenMessengerAdded(localTokenMessenger);
    }

    /**
     * @notice Remove the TokenMessenger for the local domain.
     * @dev Reverts if the TokenMessenger of the local domain is not set.
     */
    function removeLocalTokenMessenger() external onlyOwner {
        address _localTokenMessengerBeforeRemoval = localTokenMessenger;
        require(
            _localTokenMessengerBeforeRemoval != address(0),
            "No local TokenMessenger is set"
        );

        delete localTokenMessenger;
        emit LocalTokenMessengerRemoved(_localTokenMessengerBeforeRemoval);
    }

    /**
     * @notice Set tokenController to `newTokenController`, and
     * emit `SetTokenController` event.
     * @dev newTokenController must be nonzero.
     * @param newTokenController address of new token controller
     */
    function setTokenController(address newTokenController)
        external
        override
        onlyOwner
    {
        _setTokenController(newTokenController);
    }

    /**
     * @notice Get the local token address associated with the given
     * remote domain and token.
     * @param remoteDomain Remote domain
     * @param remoteToken Remote token
     * @return local token address
     */
    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken)
        external
        view
        override
        returns (address)
    {
        return _getLocalToken(remoteDomain, remoteToken);
    }

    // ============ Internal Utils ============
    /**
     * @notice Returns true if the message sender is the registered local TokenMessenger
     * @return True if the message sender is the registered local TokenMessenger
     */
    function _isLocalTokenMessenger() internal view returns (bool) {
        return
            address(localTokenMessenger) != address(0) &&
            msg.sender == address(localTokenMessenger);
    }
}
