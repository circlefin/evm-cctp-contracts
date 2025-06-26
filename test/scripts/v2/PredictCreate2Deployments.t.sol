/*
 * Copyright 2025 Circle Internet Group, Inc. All rights reserved.
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
import {PredictCreate2Deployments} from "../../../scripts/v2/PredictCreate2Deployments.s.sol";

contract PredictCreate2DeploymentsTest is ScriptV2TestUtils {
    PredictCreate2Deployments predictDeployments =
        new PredictCreate2Deployments();

    function setUp() public {
        // Only need to deploy the contracts since we're interested only in their addresses
        _deployCreate2Factory();
        _deployImplementations();
        _deployProxies();
    }

    function testPredictMessageTransmitterV2ImplAddress() public {
        address _predicted = predictDeployments.messageTransmitterV2Impl(
            address(create2Factory),
            sourceDomain,
            _version
        );
        assertEq(_predicted, address(messageTransmitterV2Impl));
    }

    function testPredictTokenMessengerV2ImplAddress() public {
        address _predicted = predictDeployments.tokenMessengerV2Impl(
            address(create2Factory),
            _messageBodyVersion
        );
        assertEq(_predicted, address(tokenMessengerV2Impl));
    }

    function testPredictMessageTransmitterV2ProxyAddress() public {
        address _predicted = predictDeployments.messageTransmitterV2Proxy(
            address(create2Factory)
        );
        assertEq(_predicted, address(messageTransmitterV2));
    }

    function testPredictTokenMessengerV2ProxyAddress() public {
        address _predicted = predictDeployments.tokenMessengerV2Proxy(
            address(create2Factory)
        );
        assertEq(_predicted, address(tokenMessengerV2));
    }

    function testPredictTokenMinterV2Address() public {
        address _predicted = predictDeployments.tokenMinterV2(
            address(create2Factory)
        );
        assertEq(_predicted, address(tokenMinterV2));
    }
}
