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

/**
 * @title IMinter
 * @notice interface for minter of tokens that are mintable, burnable, and interchangeable
 * across domains.
 */
interface IMinter {
    /**
     * @notice Mint tokens.
     * @param _mintToken Mintable token.
     * @param _to Address to receive minted tokens.
     * @param _amount Amount of tokens to mint.
     */
    function mint(
        address _mintToken,
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice Burn tokens owned by this IMinter.
     * @param _burnToken burnable token.
     * @param _amount amount of tokens to burn. Must be less than or equal to this IMinter's
     * account balance of the given `_burnToken`.
     */
    function burn(address _burnToken, uint256 _amount) external;

    /**
     * @notice Links a pair of local and remote tokens to be supported by this CircleMinter.
     * @dev Associates a (`_remoteToken`, `_localToken`) pair by updating remoteTokensToLocalTokens mapping.
     * Reverts if the remote token (for the given `_remoteDomain`) already maps to a nonzero local token.
     * Note:
     * - A remote token (on a certain remote domain) can only map to one local token, but many remote tokens
     * can map to the same local token.
     * - Setting a token pair does not enable the `_localToken` (that requires calling setLocalTokenEnabledStatus.)
     */
    function linkTokenPair(
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) external;

    /**
     * @notice Unlinks a pair of local and remote tokens for this CircleMinter.
     * @dev Removes link from `_remoteToken`, to `_localToken` for given `_remoteDomain`
     * by updating remoteTokensToLocalTokens mapping.
     * Reverts if the remote token (for the given `_remoteDomain`) already maps to the zero address.
     * Note:
     * - A remote token (on a certain remote domain) can only map to one local token, but many remote tokens
     * can map to the same local token.
     * - Unlinking a token pair does not disable the `_localToken` (that requires calling setLocalTokenEnabledStatus.)
     */
    function unlinkTokenPair(
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) external;

    /**
     * @notice Enable or disable a local token
     * @dev Sets `enabledStatus` boolean for given `_localToken`. (True to enable, false to disable.)
     * @param _localToken Local token to set enabled status of.
     * @param enabledStatus Enabled/disabled status to set for `_localToken`.
     * (True to enable, false to disable.)
     */
    function setLocalTokenEnabledStatus(address _localToken, bool enabledStatus)
        external;

    /**
     * @notice Get the enabled local token associated with the given remote domain and token.
     * @dev Reverts if unable to find an enabled local token for the
     * given (`_remoteDomain`, `_remoteToken`) pair.
     * @param _remoteDomain Remote domain
     * @param _remoteToken Remote token
     * @return Local token address
     */
    function getEnabledLocalToken(uint32 _remoteDomain, bytes32 _remoteToken)
        external
        view
        returns (address);

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
     * @param localToken local token
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` unlinked from `localToken`
     */
    event TokenPairUnlinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a local token's enabled status is set
     * @param localToken Local token
     * @param enabled Enabled status (true for enabled, false for disabled.)
     */
    event LocalTokenEnabledStatusSet(address localToken, bool enabled);
}
