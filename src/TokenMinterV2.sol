/*
 * Copyright (c) 2023, Circle Internet Financial Limited.
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
import "./TokenMinter.sol";

/**
 * @title TokenMinter
 *
 * @notice Token Minter and Burner
 * @dev Maintains registry of local mintable tokens and corresponding tokens on remote domains.
 * This registry can be used by caller to determine which token on local domain to mint for a
 * burned token on a remote domain, and vice versa.
 * It is assumed that local and remote tokens are fungible at a constant 1:1 exchange rate.
 */
contract TokenMinterV2 is TokenMinter {
    mapping(uint32 => uint256) internal minterAllowancePerSourceDomain;

    event SourceDomainMinterAllowanceUpdated(
        uint32 indexed sourceDomain,
        uint256 amount
    );

    // ============ Constructor ============
    /**
     * @param _tokenController Token controller address
     */
    constructor(address _tokenController) TokenMinter(_tokenController) {}

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
        virtual
        override
        whenNotPaused
        onlyLocalTokenMessenger
        returns (address mintToken)
    {
        address _mintToken = _getLocalToken(sourceDomain, burnToken);
        require(_mintToken != address(0), "Mint token not supported");
        // TODO: initialize minterAllowancePerSourceDomain
        uint256 mintingAllowedAmount = minterAllowancePerSourceDomain[
            sourceDomain
        ];
        require(
            amount <= mintingAllowedAmount,
            "FiatToken: mint amount exceeds minterAllowancePerSourceDomain"
        );
        minterAllowancePerSourceDomain[sourceDomain] -= amount;

        IMintBurnToken _token = IMintBurnToken(_mintToken);

        require(_token.mint(to, amount), "Mint operation failed");
        return _mintToken;
    }

    function setMinterAllowanceForDomain(uint32 sourceDomain, uint256 allowance) 
    external 
    onlyOwner {
        minterAllowancePerSourceDomain[sourceDomain] = allowance;

        emit SourceDomainMinterAllowanceUpdated(sourceDomain, allowance);
    }
}
