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
import {DeployImplementationsV2Script} from "../../../scripts/v2/DeployImplementationsV2.s.sol";
import {MessageTransmitterV2} from "../../../src/v2/MessageTransmitterV2.sol";
import {TokenMessengerV2} from "../../../src/v2/TokenMessengerV2.sol";

contract DeployImplementationsV2Test is ScriptV2TestUtils {
    DeployImplementationsV2Script deployImplementationsV2Script;

    function setUp() public {
        _deployCreate2Factory();
        _deployImplementations();
        deployImplementationsV2Script = new DeployImplementationsV2Script();
    }

    function testDeployImplementationsV2() public {
        // MessageTransmitterV2
        assertEq(messageTransmitterV2Impl.localDomain(), uint256(sourceDomain));
        assertEq(messageTransmitterV2Impl.version(), uint256(_version));

        // TokenMinterV2
        assertEq(tokenMinterV2.tokenController(), deployer);
        assertEq(tokenMinterV2.owner(), deployer);

        // TokenMessengerV2
        assertEq(
            address(tokenMessengerV2Impl.localMessageTransmitter()),
            address(expectedMessageTransmitterV2ProxyAddress)
        );
        assertEq(
            tokenMessengerV2Impl.messageBodyVersion(),
            uint256(_messageBodyVersion)
        );
    }
}
