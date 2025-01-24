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

contract MockHookTarget {
    event HookReceived(uint256 paramOne, uint256 paramTwo);

    // Returns the sum of paramOne and paramTwo
    function succeedingHook(
        uint256 paramOne,
        uint256 paramTwo
    ) external returns (uint256) {
        emit HookReceived(paramOne, paramTwo);
        return paramOne + paramTwo;
    }

    function failingHook() external pure {
        revert("Hook failure");
    }
}
