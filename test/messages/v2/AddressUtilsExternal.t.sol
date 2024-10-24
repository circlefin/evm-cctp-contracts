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
pragma abicoder v2;

import {Test} from "forge-std/Test.sol";
import {AddressUtilsExternal} from "../../../src/messages/v2/AddressUtilsExternal.sol";

contract AddressUtilsExternalTest is Test {
    function testAddressToBytes32Conversion(address _addr) public pure {
        bytes32 _addrAsBytes32 = AddressUtilsExternal.addressToBytes32(_addr);
        address _recoveredAddr = AddressUtilsExternal.bytes32ToAddress(
            _addrAsBytes32
        );
        assertEq(_recoveredAddr, _addr);
    }

    function testAddressToBytes32LeftPads(address _addr) public pure {
        bytes32 _addrAsBytes32 = AddressUtilsExternal.addressToBytes32(_addr);

        // addresses are 20 bytes, so the first 12 bytes should be 0 (left-padded)
        for (uint8 i; i < 12; i++) {
            assertEq(_addrAsBytes32[i], 0);
        }
    }
}
