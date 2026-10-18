/*
 * Copyright 2026 Circle Internet Group, Inc. All rights reserved.
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

import {ScriptV2TestUtils} from "./ScriptV2TestUtils.sol";
import {MockMintBurnToken} from "../../mocks/MockMintBurnToken.sol";

contract ScriptV2TestUtilsTest is ScriptV2TestUtils {
    function _deployAll() internal {
        _deployCreate2Factory();
        _deployImplementations();
        _deployProxies();
    }

    function testTokenAddressesDoNotDependOnEarlierDeployments() public {
        uint256 _snapshot = vm.snapshot();
        _deployAll();
        address _token = token;
        address[] memory _remoteTokens = remoteTokens;
        address _anotherRemoteToken = anotherRemoteToken;

        // Deploy again after creating a contract first, as some suites do
        vm.revertTo(_snapshot);
        new MockMintBurnToken();
        _deployAll();

        assertEq(token, _token);
        assertEq(remoteTokens.length, _remoteTokens.length);
        for (uint256 i = 0; i < _remoteTokens.length; i++) {
            assertEq(remoteTokens[i], _remoteTokens[i]);
        }
        assertEq(anotherRemoteToken, _anotherRemoteToken);
    }
}
