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

/**
 * @title TokenController
 * @notice Base contract which allows children to control tokens, including mapping
 * address of local tokens to addresses of corresponding tokens on remote domains,
 * and limiting the amount of each token that can be burned per message.
 */
abstract contract TokenController {
    // ============ Events ============
    /**
     * @notice Emitted when a token pair is linked
     * @param localToken local token to support
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` corresponding to `localToken`
     */
    event TokenPairLinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a token pair is unlinked
     * @param localToken local token address
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` unlinked from `localToken`
     */
    event TokenPairUnlinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a burn limit per message is set for a particular token
     * @param token local token address
     * @param burnLimitPerMessage burn limit per message for `token`
     */
    event SetBurnLimitPerMessage(
        address indexed token,
        uint256 burnLimitPerMessage
    );

    /**
     * @notice Emitted when token controller is set
     * @param tokenController token controller address set
     */
    event SetTokenController(address tokenController);

    // ============ State Variables ============
    // Supported burnable tokens on the local domain
    // local token (address) => maximum burn amounts per message
    mapping(address => uint256) public burnLimitsPerMessage;

    // Supported mintable tokens on remote domains, mapped to their corresponding local token
    // hash(remote domain & remote token bytes32 address) => local token (address)
    mapping(bytes32 => address) public remoteTokensToLocalTokens;

    // Role with permission to manage token address mapping across domains, and per-message burn limits
    address private _tokenController;

    // ============ Modifiers ============
    /**
     * @dev Throws if called by any account other than the tokenController.
     */
    modifier onlyTokenController() {
        require(
            msg.sender == _tokenController,
            "Caller is not tokenController"
        );
        _;
    }

    /**
     * @notice ensures that attempted burn does not exceed
     * burn limit per-message for given `burnToken`.
     * @dev reverts if allowed burn amount is 0, or burnAmount exceeds
     * allowed burn amount.
     * @param token address of token to burn
     * @param amount amount of `token` to burn
     */
    modifier onlyWithinBurnLimit(address token, uint256 amount) {
        uint256 _allowedBurnAmount = burnLimitsPerMessage[token];
        require(_allowedBurnAmount > 0, "Burn token not supported");
        require(
            amount <= _allowedBurnAmount,
            "Burn amount exceeds per tx limit"
        );
        _;
    }

    // ============ Public/External Functions  ============
    /**
     * @dev Returns the address of the tokenController
     * @return address of the tokenController
     */
    function tokenController() external view returns (address) {
        return _tokenController;
    }

    /**
     * @notice Links a pair of local and remote tokens to be supported by this TokenMinter.
     * @dev Associates a (`remoteToken`, `localToken`) pair by updating remoteTokensToLocalTokens mapping.
     * Reverts if the remote token (for the given `remoteDomain`) already maps to a nonzero local token.
     * Note:
     * - A remote token (on a certain remote domain) can only map to one local token, but many remote tokens
     * can map to the same local token.
     * - Setting a token pair does not enable the `localToken` (that requires calling setLocalTokenEnabledStatus.)
     */
    function linkTokenPair(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    ) external onlyTokenController {
        bytes32 _remoteTokensKey = _hashRemoteDomainAndToken(
            remoteDomain,
            remoteToken
        );

        // remote token must not be already linked to a local token
        require(
            remoteTokensToLocalTokens[_remoteTokensKey] == address(0),
            "Unable to link token pair"
        );

        remoteTokensToLocalTokens[_remoteTokensKey] = localToken;

        emit TokenPairLinked(localToken, remoteDomain, remoteToken);
    }

    /**
     * @notice Unlinks a pair of local and remote tokens for this TokenMinter.
     * @dev Removes link from `remoteToken`, to `localToken` for given `remoteDomain`
     * by updating remoteTokensToLocalTokens mapping.
     * Reverts if the remote token (for the given `remoteDomain`) already maps to the zero address.
     * Note:
     * - A remote token (on a certain remote domain) can only map to one local token, but many remote tokens
     * can map to the same local token.
     * - Unlinking a token pair does not disable burning the `localToken` (that requires calling setMaxBurnAmountPerMessage.)
     */
    function unlinkTokenPair(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    ) external onlyTokenController {
        bytes32 _remoteTokensKey = _hashRemoteDomainAndToken(
            remoteDomain,
            remoteToken
        );

        // remote token must be linked to a local token before unlink
        require(
            remoteTokensToLocalTokens[_remoteTokensKey] != address(0),
            "Unable to unlink token pair"
        );

        delete remoteTokensToLocalTokens[_remoteTokensKey];

        emit TokenPairUnlinked(localToken, remoteDomain, remoteToken);
    }

    /**
     * @notice Sets the maximum burn amount per message for a given `localToken`.
     * @dev Burns with amounts exceeding `burnLimitPerMessage` will revert. Mints do not
     * respect this value, so if this limit is reduced, previously burned tokens will still
     * be mintable.
     * @param localToken Local token to set the maximum burn amount per message of.
     * @param burnLimitPerMessage Maximum burn amount per message to set.
     */
    function setMaxBurnAmountPerMessage(
        address localToken,
        uint256 burnLimitPerMessage
    ) external onlyTokenController {
        burnLimitsPerMessage[localToken] = burnLimitPerMessage;

        emit SetBurnLimitPerMessage(localToken, burnLimitPerMessage);
    }

    // ============ Internal Utils ============
    /**
     * @notice Set tokenController to `newTokenController`, and
     * emit `SetTokenController` event.
     * @dev newTokenController must be nonzero.
     * @param newTokenController address of new token controller
     */
    function _setTokenController(address newTokenController) internal {
        require(
            newTokenController != address(0),
            "Invalid token controller address"
        );
        _tokenController = newTokenController;
        emit SetTokenController(newTokenController);
    }

    /**
     * @notice Get the enabled local token associated with the given remote domain and token.
     * @param remoteDomain Remote domain
     * @param remoteToken Remote token
     * @return Local token address
     */
    function _getLocalToken(uint32 remoteDomain, bytes32 remoteToken)
        internal
        view
        returns (address)
    {
        bytes32 _remoteTokensKey = _hashRemoteDomainAndToken(
            remoteDomain,
            remoteToken
        );

        return remoteTokensToLocalTokens[_remoteTokensKey];
    }

    /**
     * @notice hashes packed `_remoteDomain` and `_remoteToken`.
     * @param remoteDomain Domain where message originated from
     * @param remoteToken Address of remote token as bytes32
     * @return keccak hash of packed remote domain and token
     */
    function _hashRemoteDomainAndToken(uint32 remoteDomain, bytes32 remoteToken)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(remoteDomain, remoteToken));
    }
}
