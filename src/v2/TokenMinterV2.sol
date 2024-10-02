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

import {TokenMinter} from "../TokenMinter.sol";
import {IMintBurnToken} from "../interfaces/IMintBurnToken.sol";
import {ITokenMinterV2} from "../interfaces/v2/ITokenMinterV2.sol";

/**
 * @title TokenMinterV2
 * @notice Token Minter and Burner
 * @dev Maintains registry of local mintable tokens and corresponding tokens on remote domains.
 * This registry can be used by caller to determine which token on local domain to mint for a
 * burned token on a remote domain, and vice versa.
 * It is assumed that local and remote tokens are fungible at a constant 1:1 exchange rate.
 */
contract TokenMinterV2 is ITokenMinterV2, TokenMinter {
    // ============ Constructor ============
    /**
     * @param _tokenController Token controller address
     */
    constructor(address _tokenController) TokenMinter(_tokenController) {}

    // ============ External Functions  ============
    /**
     * @notice Mints to multiple recipients amounts of local tokens corresponding to the
     * given (`sourceDomain`, `burnToken`) pair.
     * @dev reverts if the (`sourceDomain`, `burnToken`) pair does not
     * map to a nonzero local token address. This mapping can be queried using
     * getLocalToken().
     * @param sourceDomain Source domain where `burnToken` was burned.
     * @param burnToken Burned token address as bytes32.
     * @param recipientOne Address to receive `amountOne` of minted tokens
     * @param recipientTwo Address to receive `amountTwo` of minted tokens
     * @param amountOne Amount of tokens to mint to `recipientOne`
     * @param amountTwo Amount of tokens to mint to `recipientTwo`
     * @return mintToken token minted.
     */
    function mint(
        uint32 sourceDomain,
        bytes32 burnToken,
        address recipientOne,
        address recipientTwo,
        uint256 amountOne,
        uint256 amountTwo
    )
        external
        override
        whenNotPaused
        onlyLocalTokenMessenger
        returns (address)
    {
        address _mintToken = _getLocalToken(sourceDomain, burnToken);
        require(_mintToken != address(0), "Mint token not supported");
        IMintBurnToken _token = IMintBurnToken(_mintToken);

        require(
            _token.mint(recipientOne, amountOne),
            "First mint operation failed"
        );

        require(
            _token.mint(recipientTwo, amountTwo),
            "Second mint operation failed"
        );

        return _mintToken;
    }
}
