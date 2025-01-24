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

import {DeployImplementationsV2Script} from "../../../scripts/v2/DeployImplementationsV2.s.sol";
import {DeployProxiesV2Script} from "../../../scripts/v2/DeployProxiesV2.s.sol";
import {SetupRemoteResourcesV2Script} from "../../../scripts/v2/SetupRemoteResourcesV2.s.sol";
import {RotateKeysV2Script} from "../../../scripts/v2/RotateKeysV2.s.sol";
import {MessageTransmitterV2} from "../../../src/v2/MessageTransmitterV2.sol";
import {TokenMessengerV2} from "../../../src/v2/TokenMessengerV2.sol";
import {TokenMinterV2} from "../../../src/v2/TokenMinterV2.sol";
import {MockMintBurnToken} from "../../mocks/MockMintBurnToken.sol";
import {TestUtils} from "../../TestUtils.sol";
import {Create2Factory} from "../../../src/v2/Create2Factory.sol";
import {Message} from "../../../src/messages/Message.sol";

contract ScriptV2TestUtils is TestUtils {
    uint32 _messageBodyVersion = 1;
    uint32 _version = 1;
    address token;
    uint256 deployerPK;
    address deployer;
    address attester1;
    address attester2;
    address pauser;
    address rescuer;
    address feeRecipient;
    address denyLister;

    Create2Factory create2Factory;
    MessageTransmitterV2 messageTransmitterV2;
    TokenMessengerV2 tokenMessengerV2;
    TokenMinterV2 tokenMinterV2;

    address expectedMessageTransmitterV2ProxyAddress;
    MessageTransmitterV2 messageTransmitterV2Impl;
    TokenMessengerV2 tokenMessengerV2Impl;

    address[] remoteTokens;
    uint32[] remoteDomains;
    address[] remoteTokenMessengerV2s;
    bool remoteTokenMessengerV2FromEnv = false;
    uint32 anotherRemoteDomain = 5;
    address anotherRemoteToken;

    uint256 newOwnerPK;
    address newOwner;
    address messageTransmitterV2AdminAddress;
    address tokenMessengerV2AdminAddress;

    function _deployCreate2Factory() internal {
        deployerPK = uint256(keccak256("DEPLOYTEST_DEPLOYER_PK"));
        deployer = vm.addr(deployerPK);
        vm.startBroadcast(deployerPK);
        create2Factory = new Create2Factory();
        vm.stopBroadcast();
    }

    function _deployImplementations() internal {
        vm.setEnv(
            "CREATE2_FACTORY_CONTRACT_ADDRESS",
            vm.toString(address(create2Factory))
        );
        vm.setEnv("CREATE2_FACTORY_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_MINTER_V2_OWNER_ADDRESS", vm.toString(deployer));
        vm.setEnv("TOKEN_MINTER_V2_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_CONTROLLER_ADDRESS", vm.toString(deployer));
        vm.setEnv("DOMAIN", vm.toString(uint256(sourceDomain)));
        vm.setEnv(
            "MESSAGE_BODY_VERSION",
            vm.toString(uint256(_messageBodyVersion))
        );
        vm.setEnv("VERSION", vm.toString(uint256(_version)));

        DeployImplementationsV2Script deployImplScript = new DeployImplementationsV2Script();
        deployImplScript.setUp();
        deployImplScript.run();

        messageTransmitterV2Impl = deployImplScript.messageTransmitterV2();
        tokenMinterV2 = deployImplScript.tokenMinterV2();
        tokenMessengerV2Impl = deployImplScript.tokenMessengerV2();
        expectedMessageTransmitterV2ProxyAddress = deployImplScript
            .expectedMessageTransmitterV2ProxyAddress();
    }

    function _deployProxies() internal {
        token = address(new MockMintBurnToken());
        remoteTokens.push(address(new MockMintBurnToken()));
        remoteTokens.push(address(new MockMintBurnToken()));
        remoteTokens.push(address(new MockMintBurnToken()));
        remoteDomains.push(1);
        remoteDomains.push(2);
        remoteDomains.push(3);
        remoteTokenMessengerV2s.push(
            vm.addr(uint256(keccak256("REMOTE_TOKEN_MESSENGER_V2_ADDRESS_1")))
        );
        remoteTokenMessengerV2s.push(
            vm.addr(uint256(keccak256("REMOTE_TOKEN_MESSENGER_V2_ADDRESS_2")))
        );
        remoteTokenMessengerV2s.push(
            vm.addr(uint256(keccak256("REMOTE_TOKEN_MESSENGER_V2_ADDRESS_3")))
        );
        anotherRemoteToken = address(new MockMintBurnToken());

        attester1 = vm.addr(uint256(keccak256("DEPLOYTEST_ATTESTER_1_PK")));
        attester2 = vm.addr(uint256(keccak256("DEPLOYTEST_ATTESTER_2_PK")));
        pauser = vm.addr(uint256(keccak256("DEPLOYTEST_PAUSER_PK")));
        rescuer = vm.addr(uint256(keccak256("DEPLOYTEST_RESCUER_PK")));
        feeRecipient = vm.addr(
            uint256(keccak256("DEPLOYTEST_FEE_RECIPIENT_PK"))
        );
        denyLister = vm.addr(uint256(keccak256("DEPLOYTEST_DENY_LISTER_PK")));

        messageTransmitterV2AdminAddress = vm.addr(
            uint256(keccak256("MESSAGE_TRANSMITTER_V2_ADMIN"))
        );
        tokenMessengerV2AdminAddress = vm.addr(
            uint256(keccak256("TOKEN_MESSENGER_V2_ADMIN"))
        );

        // Override env vars
        vm.setEnv("USDC_CONTRACT_ADDRESS", vm.toString(token));
        vm.setEnv("TOKEN_CONTROLLER_ADDRESS", vm.toString(deployer));
        vm.setEnv(
            "CREATE2_FACTORY_CONTRACT_ADDRESS",
            vm.toString(address(create2Factory))
        );
        vm.setEnv(
            "REMOTE_DOMAINS",
            string(
                abi.encodePacked(
                    vm.toString(uint256(remoteDomains[0])),
                    ",",
                    vm.toString(uint256(remoteDomains[1])),
                    ",",
                    vm.toString(uint256(remoteDomains[2]))
                )
            )
        );
        vm.setEnv(
            "REMOTE_USDC_CONTRACT_ADDRESSES",
            string(
                abi.encodePacked(
                    vm.toString(Message.addressToBytes32(remoteTokens[0])),
                    ",",
                    vm.toString(Message.addressToBytes32(remoteTokens[1])),
                    ",",
                    vm.toString(Message.addressToBytes32(remoteTokens[2]))
                )
            )
        );
        if (remoteTokenMessengerV2FromEnv) {
            // TODO: Figure out if there is a way to dynamically set this before setUp()
            vm.setEnv(
                "REMOTE_TOKEN_MESSENGER_V2_ADDRESSES",
                string(
                    abi.encodePacked(
                        vm.toString(
                            Message.addressToBytes32(remoteTokenMessengerV2s[0])
                        ),
                        ",",
                        vm.toString(
                            Message.addressToBytes32(remoteTokenMessengerV2s[1])
                        ),
                        ",",
                        vm.toString(
                            Message.addressToBytes32(remoteTokenMessengerV2s[2])
                        )
                    )
                )
            );
        }

        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_IMPLEMENTATION_ADDRESS",
            vm.toString(address(messageTransmitterV2Impl))
        );
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_OWNER_ADDRESS",
            vm.toString(deployer)
        );
        vm.setEnv("MESSAGE_TRANSMITTER_V2_PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_RESCUER_ADDRESS",
            vm.toString(rescuer)
        );
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_MANAGER_ADDRESS",
            vm.toString(deployer)
        );
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_1_ADDRESS",
            vm.toString(attester1)
        );
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_ATTESTER_2_ADDRESS",
            vm.toString(attester2)
        );
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_PROXY_ADMIN_ADDRESS",
            vm.toString(messageTransmitterV2AdminAddress)
        );

        vm.setEnv(
            "TOKEN_MINTER_V2_CONTRACT_ADDRESS",
            vm.toString(address(tokenMinterV2))
        );
        vm.setEnv("TOKEN_MINTER_V2_PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("TOKEN_MINTER_V2_RESCUER_ADDRESS", vm.toString(rescuer));

        vm.setEnv(
            "TOKEN_MESSENGER_V2_IMPLEMENTATION_ADDRESS",
            vm.toString(address(tokenMessengerV2Impl))
        );
        vm.setEnv("TOKEN_MESSENGER_V2_OWNER_ADDRESS", vm.toString(deployer));
        vm.setEnv("TOKEN_MESSENGER_V2_RESCUER_ADDRESS", vm.toString(rescuer));
        vm.setEnv(
            "TOKEN_MESSENGER_V2_FEE_RECIPIENT_ADDRESS",
            vm.toString(feeRecipient)
        );
        vm.setEnv(
            "TOKEN_MESSENGER_V2_DENYLISTER_ADDRESS",
            vm.toString(denyLister)
        );
        vm.setEnv(
            "TOKEN_MESSENGER_V2_PROXY_ADMIN_ADDRESS",
            vm.toString(tokenMessengerV2AdminAddress)
        );

        vm.setEnv("DOMAIN", vm.toString(uint256(sourceDomain)));
        vm.setEnv(
            "BURN_LIMIT_PER_MESSAGE",
            vm.toString(maxBurnAmountPerMessage)
        );

        vm.setEnv("CREATE2_FACTORY_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_MINTER_V2_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_CONTROLLER_KEY", vm.toString(deployerPK));

        DeployProxiesV2Script deployProxiesV2Script = new DeployProxiesV2Script();
        deployProxiesV2Script.setUp();
        deployProxiesV2Script.run();

        messageTransmitterV2 = deployProxiesV2Script.messageTransmitterV2();
        tokenMessengerV2 = deployProxiesV2Script.tokenMessengerV2();
    }

    function _setupRemoteResources() internal {
        vm.setEnv("TOKEN_MESSENGER_V2_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv(
            "TOKEN_MESSENGER_V2_CONTRACT_ADDRESS",
            vm.toString(address(tokenMessengerV2))
        );
        vm.setEnv(
            "TOKEN_MINTER_V2_CONTRACT_ADDRESS",
            vm.toString(address(tokenMinterV2))
        );
        vm.setEnv("USDC_CONTRACT_ADDRESS", vm.toString(token));
        vm.setEnv(
            "REMOTE_USDC_CONTRACT_ADDRESS",
            vm.toString(anotherRemoteToken)
        );

        vm.setEnv("REMOTE_DOMAIN", vm.toString(uint256(anotherRemoteDomain)));

        SetupRemoteResourcesV2Script setupRemoteResourcesV2Script = new SetupRemoteResourcesV2Script();
        setupRemoteResourcesV2Script.setUp();
        setupRemoteResourcesV2Script.run();
    }

    function _rotateKeys() internal {
        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_CONTRACT_ADDRESS",
            vm.toString(address(messageTransmitterV2))
        );
        // [SKIP] Use same TOKEN_MESSENGER_CONTRACT_ADDRESS
        // [SKIP] Use same TOKEN_MINTER_CONTRACT_ADDRESS
        vm.setEnv("MESSAGE_TRANSMITTER_V2_OWNER_KEY", vm.toString(deployerPK));
        vm.setEnv("TOKEN_MINTER_V2_OWNER_KEY", vm.toString(deployerPK));

        newOwnerPK = uint256(keccak256("ROTATEKEYSTEST_NEW_OWNER"));
        newOwner = vm.addr(newOwnerPK);

        vm.setEnv(
            "MESSAGE_TRANSMITTER_V2_NEW_OWNER_ADDRESS",
            vm.toString(newOwner)
        );
        vm.setEnv(
            "TOKEN_MESSENGER_V2_NEW_OWNER_ADDRESS",
            vm.toString(newOwner)
        );
        vm.setEnv("TOKEN_MINTER_V2_NEW_OWNER_ADDRESS", vm.toString(newOwner));
        vm.setEnv("NEW_TOKEN_CONTROLLER_ADDRESS", vm.toString(newOwner));

        RotateKeysV2Script rotateKeysV2Script = new RotateKeysV2Script();
        rotateKeysV2Script.setUp();
        rotateKeysV2Script.run();
    }
}
