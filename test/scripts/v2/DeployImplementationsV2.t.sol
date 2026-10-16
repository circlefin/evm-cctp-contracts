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
import {SALT_MESSAGE_TRANSMITTER, SALT_TOKEN_MINTER} from "../../../scripts/v2/Salts.sol";
import {TokenMinterV2} from "../../../src/v2/TokenMinterV2.sol";

contract DeployImplementationsV2Test is ScriptV2TestUtils {
    DeployImplementationsV2Script deployImplementationsV2Script;

    function setUp() public {
        _deployCreate2Factory();
        deployImplementationsV2Script = new DeployImplementationsV2Script();
    }

    function testDeployImplementationsV2() public {
        _deployImplementations();

        // MessageTransmitterV2
        assertEq(messageTransmitterV2Impl.localDomain(), uint256(sourceDomain));
        assertEq(messageTransmitterV2Impl.version(), uint256(_version));

        // TokenMinterV2
        address predictedTokenMinterAddress = create2Factory.computeAddress(
            SALT_TOKEN_MINTER,
            keccak256(
                abi.encodePacked(
                    type(TokenMinterV2).creationCode,
                    abi.encode(create2Factory)
                )
            )
        );
        assertEq(address(tokenMinterV2), predictedTokenMinterAddress);
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

    function testDeployImplementationsV2WhenAlreadyDeployed() public {
        _deployImplementations();
        address messageTransmitterV2Address = address(messageTransmitterV2Impl);
        address tokenMessengerV2Address = address(tokenMessengerV2Impl);
        address tokenMinterV2Address = address(tokenMinterV2);

        // Running the script again reuses all three contracts.
        _deployImplementations();

        assertEq(
            address(messageTransmitterV2Impl),
            messageTransmitterV2Address
        );
        assertEq(address(tokenMessengerV2Impl), tokenMessengerV2Address);
        assertEq(address(tokenMinterV2), tokenMinterV2Address);
        assertEq(tokenMinterV2.owner(), deployer);
    }

    function testDeployImplementationsV2WhenOnlyTokenMessengerV2IsMissing()
        public
    {
        // Deploy MessageTransmitterV2 and TokenMinterV2 at the addresses the
        // script uses, as on a chain where only TokenMessengerV2 changed.
        vm.startPrank(deployer);
        address messageTransmitterV2Address = create2Factory.deploy(
            0,
            SALT_MESSAGE_TRANSMITTER,
            abi.encodePacked(
                type(MessageTransmitterV2).creationCode,
                abi.encode(sourceDomain, _version)
            )
        );
        address tokenMinterV2Address = create2Factory.deploy(
            0,
            SALT_TOKEN_MINTER,
            abi.encodePacked(
                type(TokenMinterV2).creationCode,
                abi.encode(create2Factory)
            )
        );
        vm.stopPrank();

        _deployImplementations();

        // The existing contracts are reused and TokenMinterV2 keeps its owner.
        assertEq(
            address(messageTransmitterV2Impl),
            messageTransmitterV2Address
        );
        assertEq(address(tokenMinterV2), tokenMinterV2Address);
        assertEq(tokenMinterV2.owner(), address(create2Factory));
        assertEq(tokenMinterV2.pendingOwner(), address(0));

        // TokenMessengerV2 is deployed.
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
