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

// Test helper to use an alternate implementation to test proxy
contract MockProxyImplementation {
    address public storedAddr;

    function foo() external pure returns (bytes memory response) {
        response = bytes("bar");
    }

    function setStoredAddr(address _storedAddr) external {
        storedAddr = _storedAddr;
    }
}

// Alternate implementation with distinct ABI
contract MockAlternateProxyImplementation {
    uint256[1] __gap;
    address public storedAddrAlternate;

    function baz() external pure returns (bytes memory response) {
        response = bytes("qux");
    }

    function setStoredAddrAlternate(address _storedAddr) external {
        storedAddrAlternate = _storedAddr;
    }
}
