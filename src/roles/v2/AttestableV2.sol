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

import {Attestable} from "../Attestable.sol";

/**
 * @title AttestableV2
 * @notice Builds on Attestable by adding a storage gap to enable more flexible future additions to
 * any AttestableV2 child contracts.
 */
contract AttestableV2 is Attestable {
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[20] private __gap;

    // ============ Constructor ============
    /**
     * @dev The constructor sets the original attester manager and the first enabled attester to the
     * msg.sender address.
     */
    constructor() Attestable(msg.sender) {}
}
