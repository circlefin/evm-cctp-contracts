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

import {ScriptV2TestUtils} from "./ScriptV2TestUtils.sol";

contract DeployTest is ScriptV2TestUtils {
    function setUp() public {
        _deploy();
    }

    function testDeployMessageTransmitter() public {
        // domain
        assertEq(messageTransmitter.localDomain(), uint256(sourceDomain));

        // attester
        assertEq(messageTransmitter.attesterManager(), deployer);
        assertTrue(messageTransmitter.isEnabledAttester(deployer));

        // maxMessageBodySize
        assertEq(messageTransmitter.maxMessageBodySize(), maxMessageBodySize);

        // version
        assertEq(messageTransmitter.version(), uint256(version));

        // pauser
        assertEq(messageTransmitter.pauser(), pauser);

        // rescuer
        assertEq(messageTransmitter.rescuer(), rescuer);
    }

    function testDeployTokenMessenger() public {
        // message transmitter
        assertEq(
            address(tokenMessenger.localMessageTransmitter()),
            address(messageTransmitter)
        );

        // message body version
        assertEq(
            tokenMessenger.messageBodyVersion(),
            uint256(_messageBodyVersion)
        );

        // rescuer
        assertEq(tokenMessenger.rescuer(), rescuer);
    }

    function testDeployTokenMinter() public {
        // token controller
        assertEq(tokenMinter.tokenController(), deployer);

        // token messenger
        assertEq(tokenMinter.localTokenMessenger(), address(tokenMessenger));

        // pauser
        assertEq(tokenMinter.pauser(), pauser);

        // rescuer
        assertEq(tokenMinter.rescuer(), rescuer);
    }

    function testAddMinterAddressToTokenMessenger() public {
        assertEq(address(tokenMessenger.localMinter()), address(tokenMinter));
    }

    function testLinkTokenPair() public {
        // max burn per msg
        assertEq(
            tokenMinter.burnLimitsPerMessage(token),
            maxBurnAmountPerMessage
        );

        // linked token pair
        bytes32 remoteKey = keccak256(
            abi.encodePacked(
                destinationDomain,
                bytes32(uint256(uint160(remoteToken)))
            )
        );
        assertEq(tokenMinter.remoteTokensToLocalTokens(remoteKey), token);
    }

    function testAddRemoteTokenMessenger() public {
        assertEq(
            tokenMessenger.remoteTokenMessengers(destinationDomain),
            bytes32(uint256(uint160(remoteTokenMessengerAddress)))
        );
    }
}
