/*
 * Copyright (c) 2024, Circle Internet Financial Limited.
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
pragma abicoder v2;

import {ScriptV2TestUtils} from "./ScriptV2TestUtils.sol";

contract SetupRemoteResourcesTest is ScriptV2TestUtils {
    function setUp() public {
        _deployCreate2Factory();
        _deployImplementations();
        _deployProxies();
        _setupRemoteResources();
    }

    function testLinkTokenPair() public {
        bytes32 remoteKey = keccak256(
            abi.encodePacked(
                anotherRemoteDomain,
                bytes32(uint256(uint160(anotherRemoteToken)))
            )
        );
        assertEq(tokenMinterV2.remoteTokensToLocalTokens(remoteKey), token);
    }

    function testAddRemoteTokenMessenger() public {
        assertEq(
            tokenMessengerV2.remoteTokenMessengers(anotherRemoteDomain),
            bytes32(uint256(uint160(address(tokenMessengerV2))))
        );
    }
}
