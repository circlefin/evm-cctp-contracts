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

import {DeployV2Script} from "../../scripts/v2/1_deploy.s.sol";
import {SetupSecondAttesterScript} from "../../scripts/v2/2_setupSecondAttester.s.sol";
import {SetupRemoteResourcesScript} from "../../scripts/v2/3_setupRemoteResources.s.sol";
import {RotateKeysScript} from "../../scripts/v2/4_rotateKeys.s.sol";
import {MessageTransmitter} from "../../src/MessageTransmitter.sol";
import {TokenMessenger} from "../../src/TokenMessenger.sol";
import {TokenMinter} from "../../src/TokenMinter.sol";
import {MockMintBurnToken} from "../mocks/MockMintBurnToken.sol";
import {TestUtils} from "../TestUtils.sol";

contract ScriptV2TestUtils is TestUtils {
    uint32 _messageBodyVersion = 0;
    address token;
    address remoteToken;
    address remoteTokenMessengerAddress;
    uint256 deployerPK;
    address deployer;
    address pauser;
    address rescuer;
    MessageTransmitter messageTransmitter;
    TokenMessenger tokenMessenger;
    TokenMinter tokenMinter;

    uint32 anotherRemoteDomain = 2;
    address anotherRemoteToken;
    address anotherRemoteTokenMessengerAddress;

    uint256 newOwnerPK;
    address newOwner;

    function _deploy() internal {
        token = address(new MockMintBurnToken());
        remoteToken = address(new MockMintBurnToken());

        deployerPK = uint256(keccak256("DEPLOYTEST_DEPLOYER_PK"));
        deployer = vm.addr(deployerPK);
        pauser = vm.addr(uint256(keccak256("DEPLOYTEST_PAUSER_PK")));
        rescuer = vm.addr(uint256(keccak256("DEPLOYTEST_RESCUER_PK")));

        // Override env vars
        vm.setEnv("MESSAGE_TRANSMITTER_DEPLOYER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_MESSENGER_DEPLOYER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_MINTER_DEPLOYER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_CONTROLLER_DEPLOYER_KEY", vm.toString(deployerPK));

        vm.setEnv("ATTESTER_ADDRESS", vm.toString(deployer));
        vm.setEnv("USDC_CONTRACT_ADDRESS", vm.toString(token));
        vm.setEnv("TOKEN_CONTROLLER_ADDRESS", vm.toString(deployer));
        vm.setEnv(
            "BURN_LIMIT_PER_MESSAGE",
            vm.toString(maxBurnAmountPerMessage)
        );

        vm.setEnv("REMOTE_USDC_CONTRACT_ADDRESS", vm.toString(remoteToken));

        remoteTokenMessengerAddress = vm.addr(
            uint256(keccak256("REMOTE_TOKEN_MESSENGER_ADDRESS"))
        );
        vm.setEnv(
            "REMOTE_TOKEN_MESSENGER_ADDRESS",
            vm.toString(remoteTokenMessengerAddress)
        );

        vm.setEnv("DOMAIN", vm.toString(uint256(sourceDomain)));
        vm.setEnv("REMOTE_DOMAIN", vm.toString(uint256(destinationDomain)));

        vm.setEnv("MESSAGE_TRANSMITTER_PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("TOKEN_MINTER_PAUSER_ADDRESS", vm.toString(pauser));

        vm.setEnv("MESSAGE_TRANSMITTER_RESCUER_ADDRESS", vm.toString(rescuer));
        vm.setEnv("TOKEN_MESSENGER_RESCUER_ADDRESS", vm.toString(rescuer));
        vm.setEnv("TOKEN_MINTER_RESCUER_ADDRESS", vm.toString(rescuer));

        DeployV2Script deployScript = new DeployV2Script();
        deployScript.setUp();
        deployScript.run();

        messageTransmitter = deployScript.messageTransmitter();
        tokenMessenger = deployScript.tokenMessenger();
        tokenMinter = deployScript.tokenMinter();
    }

    function _setupSecondAttester() internal {
        vm.setEnv(
            "MESSAGE_TRANSMITTER_CONTRACT_ADDRESS",
            vm.toString(address(messageTransmitter))
        );
        // [SKIP] Use same MESSAGE_TRANSMITTER_DEPLOYER_KEY
        // Use same attester manager, deployer
        vm.setEnv("NEW_ATTESTER_MANAGER_ADDRESS", vm.toString(deployer));
        vm.setEnv("SECOND_ATTESTER_ADDRESS", vm.toString(secondAttester));

        SetupSecondAttesterScript setupSecondAttesterScript = new SetupSecondAttesterScript();
        setupSecondAttesterScript.setUp();
        setupSecondAttesterScript.run();
    }

    function _setupRemoteResources() internal {
        // [SKIP] Use same TOKEN_MESSENGER_DEPLOYER_KEY
        // Use same TOKEN_CONTROLLER_DEPLOYER_KEY as TOKEN_CONTROLLER_KEY
        vm.setEnv("TOKEN_CONTROLLER_KEY", vm.toString(deployerPK));
        vm.setEnv(
            "TOKEN_MESSENGER_CONTRACT_ADDRESS",
            vm.toString(address(tokenMessenger))
        );
        vm.setEnv(
            "TOKEN_MINTER_CONTRACT_ADDRESS",
            vm.toString(address(tokenMinter))
        );
        vm.setEnv("USDC_CONTRACT_ADDRESS", vm.toString(token));
        vm.setEnv(
            "REMOTE_USDC_CONTRACT_ADDRESS",
            vm.toString(anotherRemoteToken)
        );

        anotherRemoteTokenMessengerAddress = vm.addr(
            uint256(keccak256("ANOTHER_REMOTE_TOKEN_MESSENGER_ADDRESS"))
        );
        vm.setEnv(
            "REMOTE_TOKEN_MESSENGER_ADDRESS",
            vm.toString(anotherRemoteTokenMessengerAddress)
        );
        vm.setEnv("REMOTE_DOMAIN", vm.toString(uint256(anotherRemoteDomain)));

        SetupRemoteResourcesScript setupRemoteResourcesScript = new SetupRemoteResourcesScript();
        setupRemoteResourcesScript.setUp();
        setupRemoteResourcesScript.run();
    }

    function _rotateKeys() internal {
        // [SKIP] Use same MESSAGE_TRANSMITTER_CONTRACT_ADDRESS
        // [SKIP] Use same TOKEN_MESSENGER_CONTRACT_ADDRESS
        // [SKIP] Use same TOKEN_MINTER_CONTRACT_ADDRESS
        // [SKIP] Use same MESSAGE_TRANSMITTER_DEPLOYER_KEY
        // [SKIP] Use same TOKEN_MESSENGER_DEPLOYER_KEY
        // [SKIP] Use same TOKEN_MINTER_DEPLOYER_KEY

        newOwnerPK = uint256(keccak256("ROTATEKEYSTEST_NEW_OWNER"));
        newOwner = vm.addr(newOwnerPK);

        vm.setEnv(
            "MESSAGE_TRANSMITTER_NEW_OWNER_ADDRESS",
            vm.toString(newOwner)
        );
        vm.setEnv("TOKEN_MESSENGER_NEW_OWNER_ADDRESS", vm.toString(newOwner));
        vm.setEnv("TOKEN_MINTER_NEW_OWNER_ADDRESS", vm.toString(newOwner));
        vm.setEnv("NEW_TOKEN_CONTROLLER_ADDRESS", vm.toString(newOwner));

        RotateKeysScript rotateKeysScript = new RotateKeysScript();
        rotateKeysScript.setUp();
        rotateKeysScript.run();
    }
}
