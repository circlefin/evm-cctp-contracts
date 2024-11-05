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

import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";
import {MockMintBurnToken} from "../mocks/MockMintBurnToken.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {BurnMessageV2} from "../../src/messages/v2/BurnMessageV2.sol";
import {MessageV2} from "../../src/messages/v2/MessageV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {TestUtils} from "../TestUtils.sol";
import {Vm} from "forge-std/Vm.sol";

contract TokenMessengerV2IntegrationTest is TestUtils {
    event MessageSent(bytes message);

    // Libraries
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;
    using MessageV2 for bytes29;
    using AddressUtils for address;

    // Constants
    uint32 localDomain = 0;
    uint32 remoteDomain = 1;
    uint32 messageVersion = 1;
    uint32 messageBodyVersion = 1;

    MessageTransmitterV2 localMessageTransmitter;
    MessageTransmitterV2 remoteMessageTransmitter;

    TokenMessengerV2 localTokenMessenger;
    TokenMessengerV2 remoteTokenMessenger;

    MockMintBurnToken localToken = new MockMintBurnToken();
    MockMintBurnToken remoteToken = new MockMintBurnToken();

    TokenMinterV2 localTokenMinter = new TokenMinterV2(tokenController);
    TokenMinterV2 remoteTokenMinter = new TokenMinterV2(tokenController);

    // Roles
    address localDepositor =
        address(0xBcd4042DE499D14e55001CcbB24a551F3b954096);
    address localMintRecipient =
        address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    address remoteDepositor =
        address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
    address remoteMintRecipient =
        address(0x90F79bf6EB2c4f870365E785982E1f101E93b906);

    address localDeployer = address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
    address remoteDeployer =
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f);

    address tokenDeployer = address(0x15d34Aaf54267dB7d7c367839aaF71A00A2C6a64);

    // Constants

    uint256 localDepositAmount = 50_000_000_000;
    uint256 localFeeExecuted = 50_000_000;

    // Precomputed messages
    // Reformatted MessageSent from local domain depositForBurn with:
    // --nonce: keccak256("LocalNonce")
    // --finalityThresholdExecuted: 1000
    // --feeExecuted: 50_000_000
    // --expirationBlock: 0
    function _localMessageSent() internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                hex"00000001000000000000000109ac09a5866905247c049066d77ced39929878c828a4198405db6608023c54fb00000000000000000000000093c7a6d00849c44ef3e92e95dceffccd447909ae000000000000000000000000ca8b49076d1a8039599e24979abf819af784c27a00000000000000000000000090f79bf6eb2c4f870365e785982e1f101e93b906000003e8000003e80000000100000000000000000000000024FA1F38FfE8bE6711872c6e0D662D83E524f0cE00000000000000000000000090f79bf6eb2c4f870365e785982e1f101e93b9060000000000000000000000000000000000000000000000000000000ba43b7400000000000000000000000000bcd4042de499d14e55001ccbb24a551f3b9540960000000000000000000000000000000000000000000000000000000002faf0800000000000000000000000000000000000000000000000000000000002faf0800000000000000000000000000000000000000000000000000000000000000000"
            );
    }

    function setUp() public {
        // Attesters
        address[] memory _attesters = new address[](1);
        _attesters[0] = attester;

        vm.startPrank(tokenDeployer);
        localToken = new MockMintBurnToken();
        remoteToken = new MockMintBurnToken();
        vm.stopPrank();

        // Local MessageTransmitterV2
        vm.startPrank(localDeployer);
        MessageTransmitterV2 localMessageTransmitterImpl = new MessageTransmitterV2(
                localDomain,
                messageVersion
            );
        AdminUpgradableProxy proxy = new AdminUpgradableProxy(
            address(localMessageTransmitterImpl),
            localDeployer,
            abi.encodeWithSelector(
                MessageTransmitterV2.initialize.selector,
                localDeployer,
                localDeployer,
                localDeployer,
                localDeployer,
                _attesters,
                1,
                maxMessageBodySize
            )
        );
        localMessageTransmitter = MessageTransmitterV2(address(proxy));

        // Local TokenMessengerV2
        TokenMessengerV2 localTokenMessengerImpl = new TokenMessengerV2(
            address(localMessageTransmitter),
            messageBodyVersion
        );
        proxy = new AdminUpgradableProxy(
            address(localTokenMessengerImpl),
            localDeployer,
            abi.encodeWithSelector(
                TokenMessengerV2.initialize.selector,
                localDeployer, // owner
                localDeployer, // rescuer
                localDeployer, // feeRecipient
                localDeployer, // denylister
                address(localTokenMinter),
                new uint32[](0),
                new bytes32[](0)
            )
        );
        localTokenMessenger = TokenMessengerV2(address(proxy));
        vm.stopPrank();

        // Remote MessageTransmitterV2
        vm.startPrank(remoteDeployer);
        MessageTransmitterV2 remoteMessageTransmitterImpl = new MessageTransmitterV2(
                remoteDomain,
                messageVersion
            );
        proxy = new AdminUpgradableProxy(
            address(remoteMessageTransmitterImpl),
            remoteDeployer,
            abi.encodeWithSelector(
                MessageTransmitterV2.initialize.selector,
                remoteDeployer,
                remoteDeployer,
                remoteDeployer,
                remoteDeployer,
                _attesters,
                1,
                maxMessageBodySize
            )
        );
        remoteMessageTransmitter = MessageTransmitterV2(address(proxy));

        // Remote TokenMessengerV2
        TokenMessengerV2 remoteTokenMessengerImpl = new TokenMessengerV2(
            address(remoteMessageTransmitter),
            messageBodyVersion
        );
        uint32[] memory _remoteDomains = new uint32[](1);
        bytes32[] memory _remoteTokenMessengerAddresses = new bytes32[](1);

        _remoteDomains[0] = 0; // configure localDomain, on remoteDomain
        _remoteTokenMessengerAddresses[0] = address(localTokenMessenger)
            .toBytes32();

        proxy = new AdminUpgradableProxy(
            address(remoteTokenMessengerImpl),
            remoteDeployer,
            abi.encodeWithSelector(
                TokenMessengerV2.initialize.selector,
                remoteDeployer, // owner
                remoteDeployer, // rescuer
                remoteDeployer, // feeRecipient
                remoteDeployer, // denylister
                address(remoteTokenMinter),
                _remoteDomains,
                _remoteTokenMessengerAddresses
            )
        );
        remoteTokenMessenger = TokenMessengerV2(address(proxy));
        vm.stopPrank();

        // Configure remote TokenMessenger on local domain
        vm.startPrank(localDeployer);
        localTokenMessenger.addRemoteTokenMessenger(
            remoteDomain,
            address(remoteTokenMessenger).toBytes32()
        );
        vm.stopPrank();

        // Link token pair on local domain
        linkTokenPair(
            localTokenMinter,
            address(localToken),
            remoteDomain,
            address(remoteToken).toBytes32()
        );

        // Link token pair on remote domain
        linkTokenPair(
            remoteTokenMinter,
            address(remoteToken),
            localDomain,
            address(localToken).toBytes32()
        );

        // Set maxBurnAmountPerMessage
        vm.startPrank(tokenController);
        localTokenMinter.setMaxBurnAmountPerMessage(
            address(localToken),
            1_000_000_000_000
        );
        remoteTokenMinter.setMaxBurnAmountPerMessage(
            address(remoteToken),
            1_000_000_000_000
        );
        vm.stopPrank();

        // Configure TokenMessengers on TokenMinters
        localTokenMinter.addLocalTokenMessenger(address(localTokenMessenger));
        remoteTokenMinter.addLocalTokenMessenger(address(remoteTokenMessenger));

        // Mint ERC20 tokens and setup allowances
        localToken.mint(localDepositor, localDepositAmount);

        vm.prank(localDepositor);
        localToken.approve(address(localTokenMessenger), localDepositAmount);
    }

    // Tests

    function testDepositForBurn_succeedsFromLocalDomain() public {
        assertEq(localToken.totalSupply(), localDepositAmount);
        assertEq(localToken.balanceOf(localDepositor), localDepositAmount);

        vm.startPrank(localDepositor);
        localTokenMessenger.depositForBurn(
            localDepositAmount,
            remoteDomain,
            remoteMintRecipient.toBytes32(),
            address(localToken),
            remoteMintRecipient.toBytes32(),
            localFeeExecuted,
            1000
        );
        vm.stopPrank();

        assertEq(localToken.totalSupply(), 0);
        assertEq(localToken.balanceOf(localDepositor), 0);
    }

    function testReceiveMessage_succeedsOnRemoteDomain() public {
        bytes memory _message = _localMessageSent();
        _sanityCheckMessageSent(_message);

        bytes memory _attestation = _signMessageWithAttesterPK(_message);

        assertEq(remoteToken.totalSupply(), 0);
        assertEq(remoteToken.balanceOf(remoteMintRecipient), 0);

        vm.prank(remoteMintRecipient);
        remoteMessageTransmitter.receiveMessage(_message, _attestation);

        assertEq(remoteToken.totalSupply(), localDepositAmount);
        assertEq(
            remoteToken.balanceOf(remoteMintRecipient),
            localDepositAmount - localFeeExecuted
        );
        assertEq(
            remoteToken.balanceOf(remoteDeployer), // feeRecipient
            localFeeExecuted
        );
    }

    // Test utils

    // Helper to validate that the message doesn't have unexpected values
    // according to the test harness, since we precompute the MessageSent for delivery
    // on the destination chain, with nonce, finalityThresholdExecuted, feeExecuted, and
    // expirationBlock encoded off-chain.
    function _sanityCheckMessageSent(bytes memory _message) internal view {
        bytes29 _msg = _message.ref(0);

        assertEq(uint256(MessageV2._getVersion(_msg)), uint256(messageVersion));
        assertEq(
            uint256(MessageV2._getSourceDomain(_msg)),
            uint256(localDomain)
        );
        assertEq(
            uint256(MessageV2._getDestinationDomain(_msg)),
            uint256(remoteDomain)
        );
        assertTrue(MessageV2._getNonce(_msg) > 0);
        assertEq(
            MessageV2._getSender(_msg),
            address(localTokenMessenger).toBytes32()
        );
        assertEq(
            MessageV2._getRecipient(_msg),
            address(remoteTokenMessenger).toBytes32()
        );
        assertEq(
            MessageV2._getDestinationCaller(_msg),
            remoteMintRecipient.toBytes32()
        );
        assertEq(
            uint256(MessageV2._getMinFinalityThreshold(_msg)),
            uint256(1000)
        );
        assertEq(
            uint256(MessageV2._getFinalityThresholdExecuted(_msg)),
            uint256(1000)
        );

        bytes29 _burnMessageV2 = _msg._getMessageBody();

        assertEq(
            uint256(BurnMessageV2._getVersion(_burnMessageV2)),
            uint256(messageBodyVersion)
        );
        assertEq(
            BurnMessageV2._getBurnToken(_burnMessageV2),
            address(localToken).toBytes32()
        );
        assertEq(
            BurnMessageV2._getMintRecipient(_burnMessageV2),
            remoteMintRecipient.toBytes32()
        );
        assertEq(BurnMessageV2._getAmount(_burnMessageV2), localDepositAmount);
        assertEq(
            BurnMessageV2._getMessageSender(_burnMessageV2),
            localDepositor.toBytes32()
        );
        assertEq(BurnMessageV2._getMaxFee(_burnMessageV2), localFeeExecuted);
        assertEq(
            BurnMessageV2._getFeeExecuted(_burnMessageV2),
            localFeeExecuted
        );
        assertEq(BurnMessageV2._getExpirationBlock(_burnMessageV2), 0);
    }
}
