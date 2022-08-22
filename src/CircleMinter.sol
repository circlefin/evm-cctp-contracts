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

import "./interfaces/IMinter.sol";
import "./interfaces/IMintBurnToken.sol";

/**
 * @title CircleMinter
 * @notice Minter and burner of Circle-issued stablecoins.
 * @dev Maintains registry of local mintable tokens and corresponding tokens on remote domains.
 * This registry can be used by caller to determine which token on local domain to mint for a
 * burned token on a remote domain, and vice versa.
 */
contract CircleMinter is IMinter {
    // Supported mintable tokens on the local domain
    // local token (address) => supported (bool)
    mapping(address => bool) public localTokens;

    // Supported mintable tokens on remote domains, mapped to their corresponding local token
    // hash(remote domain & remote token bytes32 address) => local token (address)
    mapping(bytes32 => address) public remoteTokensToLocalTokens;

    /**
     * @notice Mint tokens.
     * @param _mintToken Mintable Circle-issued token address.
     * @param _to Address to receive minted tokens.
     * @param _amount Amount of tokens to mint. Must be less than or equal
     * to the minterAllowance of this CircleMinter for given `_mintToken`.
     */
    // TODO [BRAAV-11741] onlyOwner (CircleBridge contract)
    function mint(
        address _mintToken,
        address _to,
        uint256 _amount
    ) external override {
        require(localTokens[_mintToken], "Given mint token is not supported");

        IMintBurnToken _token = IMintBurnToken(_mintToken);
        _token.mint(_to, _amount);
    }

    /**
     * @notice Burn tokens owned by this CircleMinter.
     * @param _remoteToken burnable Circle-issued token.
     * @param _amount amount of tokens to burn. Must be less than or equal to this
     * CircleMinter's balance of given `_remoteToken`.
     */
    // TODO [BRAAV-11741] onlyOwner (CircleBridge contract)
    function burn(address _remoteToken, uint256 _amount) external override {
        require(localTokens[_remoteToken], "Given burn token is not supported");

        IMintBurnToken _token = IMintBurnToken(_remoteToken);
        _token.burn(_amount);
    }

    /**
     * @notice Links a pair of local and remote tokens to be supported by this CircleMinter.
     * @dev Associates a (`_remoteToken`, `_localToken`) pair by updating remoteTokensToLocalTokens mapping.
     * Reverts if the remote token (for the given `_remoteDomain`) already maps to a nonzero local token.
     * Note:
     * - A remote token (on a certain remote domain) can only map to one local token, but many remote tokens
     * can map to the same local token.
     * - Setting a token pair does not enable the `_localToken` (that requires calling setLocalTokenEnabledStatus.)
     */
    // TODO BRAAV-11741 onlyTokensManager
    function linkTokenPair(
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) external override {
        bytes32 remoteTokensKey = _hashRemoteDomainAndToken(
            _remoteDomain,
            _remoteToken
        );

        require(
            remoteTokensToLocalTokens[remoteTokensKey] == address(0),
            "Unable to link token pair, remote token already linked to a local token"
        );

        remoteTokensToLocalTokens[remoteTokensKey] = _localToken;

        emit TokenPairLinked(_localToken, _remoteDomain, _remoteToken);
    }

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
    // TODO BRAAV-11741 onlyTokensManager
    function unlinkTokenPair(
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) external override {
        bytes32 remoteTokensKey = _hashRemoteDomainAndToken(
            _remoteDomain,
            _remoteToken
        );

        require(
            remoteTokensToLocalTokens[remoteTokensKey] != address(0),
            "Unable to unlink token pair, remote token is already not linked to any local token"
        );

        remoteTokensToLocalTokens[remoteTokensKey] = address(0);

        emit TokenPairUnlinked(_localToken, _remoteDomain, _remoteToken);
    }

    /**
     * @notice Enable or disable a local token
     * @dev Sets `enabledStatus` boolean for given `_localToken`. (True to enable, false to disable.)
     * @param _localToken Local token to set enabled status of.
     * @param _enabledStatus Enabled/disabled status to set for `_localToken`.
     * (True to enable, false to disable.)
     */
    // TODO BRAAV-11741 onlyTokensManager
    function setLocalTokenEnabledStatus(
        address _localToken,
        bool _enabledStatus
    ) external override {
        localTokens[_localToken] = _enabledStatus;

        emit LocalTokenEnabledStatusSet(_localToken, _enabledStatus);
    }

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
        override
        returns (address)
    {
        bytes32 _remoteTokensKey = _hashRemoteDomainAndToken(
            _remoteDomain,
            _remoteToken
        );

        address _localToken = remoteTokensToLocalTokens[_remoteTokensKey];

        require(
            _localToken != address(0) && localTokens[_localToken],
            "No enabled local token is associated with remote domain and token pair"
        );

        return _localToken;
    }

    /**
     * @notice hashes packed `_remoteDomain` and `_remoteToken`.
     * @param _remoteDomain Domain where message originated from
     * @param _remoteToken Address of remote token as bytes32
     * @return keccak hash of packed remote domain and token
     */
    function _hashRemoteDomainAndToken(
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_remoteDomain, _remoteToken));
    }

    // TODO [BRAAV-11741] add rescuer for other tokens
}
