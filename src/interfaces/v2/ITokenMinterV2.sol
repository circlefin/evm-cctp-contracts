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

import {ITokenMinter} from "../ITokenMinter.sol";

/**
 * @title ITokenMinterV2
 * @notice Interface for a minter of tokens that are mintable, burnable, and interchangeable
 * across domains.
 */
interface ITokenMinterV2 is ITokenMinter {
    /**
     * @notice Mints to multiple recipients amounts of tokens corresponding to the
     * given (`sourceDomain`, `burnToken`) pair.
     * @param sourceDomain Source domain where `burnToken` was burned.
     * @param burnToken Burned token address as bytes32.
     * @param recipientOne Address to receive `amountOne` of minted tokens
     * @param recipientTwo Address to receive `amountTwo` of minted tokens
     * @param amountOne Amount of tokens to mint to `recipientOne`
     * @param amountTwo Amount of tokens to mint to `recipientTwo`
     * @return mintToken Address of the token that was minted, corresponding to the (`sourceDomain`, `burnToken`) pair
     */
    function mint(
        uint32 sourceDomain,
        bytes32 burnToken,
        address recipientOne,
        address recipientTwo,
        uint256 amountOne,
        uint256 amountTwo
    ) external returns (address);
}
