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

import {Initializable} from "../../src/proxy/Initializable.sol";

contract MockInitializableImplementation is Initializable {
    address public addr;
    uint256 public num;

    function initialize(address _addr, uint256 _num) external initializer {
        addr = _addr;
        num = _num;
    }

    function initializeV2() external reinitializer(2) {}

    function initializeV3() external reinitializer(3) {}

    function supportingInitializer() public view onlyInitializing {}

    function disableInitializers() external {
        _disableInitializers();
    }

    function initializedVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function initializing() external view returns (bool) {
        return _isInitializing();
    }
}
