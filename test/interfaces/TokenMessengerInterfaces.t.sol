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
import {ITokenMessenger} from "../../src/interfaces/ITokenMessenger.sol";
import {TokenMessenger} from "../../src/TokenMessenger.sol";
import {ITokenMessengerV2} from "../../src/interfaces/v2/ITokenMessengerV2.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";

/**
 * @notice Conformance tests proving the integrator-facing interfaces match the
 * external ABI of the concrete TokenMessenger contracts. Each function selector
 * declared on an interface must be identical to the selector on the concrete
 * contract; if a signature ever drifts, these assertions fail.
 * @dev Selector equality is independent of return-type, so the interfaces may
 * declare lighter return types (e.g. `address` for `localMinter()`) while still
 * resolving to the exact same external function on the deployed contract.
 */
contract TokenMessengerInterfacesTest is Test {
    // ============ v1 ============
    function testV1_DepositEntrypointSelectorsMatch() public {
        assertEq(
            ITokenMessenger.depositForBurn.selector,
            TokenMessenger.depositForBurn.selector
        );
        assertEq(
            ITokenMessenger.depositForBurnWithCaller.selector,
            TokenMessenger.depositForBurnWithCaller.selector
        );
        assertEq(
            ITokenMessenger.replaceDepositForBurn.selector,
            TokenMessenger.replaceDepositForBurn.selector
        );
        assertEq(
            ITokenMessenger.handleReceiveMessage.selector,
            TokenMessenger.handleReceiveMessage.selector
        );
    }

    function testV1_ViewSelectorsMatch() public {
        // These accessors are public state variables on the concrete contract;
        // their auto-generated getter selectors are keccak256("name(args)")[:4].
        assertEq(
            ITokenMessenger.messageBodyVersion.selector,
            bytes4(keccak256("messageBodyVersion()"))
        );
        assertEq(
            ITokenMessenger.localMinter.selector,
            bytes4(keccak256("localMinter()"))
        );
        assertEq(
            ITokenMessenger.localMessageTransmitter.selector,
            bytes4(keccak256("localMessageTransmitter()"))
        );
        assertEq(
            ITokenMessenger.remoteTokenMessengers.selector,
            bytes4(keccak256("remoteTokenMessengers(uint32)"))
        );
    }

    // Note on events: Solidity 0.7.6 exposes no `Event.selector` member, so event
    // topic0 conformance cannot be asserted here without an emit. The DepositForBurn
    // and MintAndWithdraw events are mirrored verbatim from the concrete contracts,
    // and their shapes are exercised against the deployed contracts (via expectEmit)
    // in TokenMessenger.t.sol and test/v2/TokenMessengerV2.t.sol.

    // ============ v2 ============
    function testV2_DepositEntrypointSelectorsMatch() public {
        assertEq(
            ITokenMessengerV2.depositForBurn.selector,
            TokenMessengerV2.depositForBurn.selector
        );
        assertEq(
            ITokenMessengerV2.depositForBurnWithHook.selector,
            TokenMessengerV2.depositForBurnWithHook.selector
        );
        assertEq(
            ITokenMessengerV2.getMinFeeAmount.selector,
            TokenMessengerV2.getMinFeeAmount.selector
        );
    }

    function testV2_ViewSelectorsMatch() public {
        // These accessors are public state variables on the concrete contract;
        // their auto-generated getter selectors are keccak256("name(args)")[:4].
        assertEq(
            ITokenMessengerV2.messageBodyVersion.selector,
            bytes4(keccak256("messageBodyVersion()"))
        );
        assertEq(
            ITokenMessengerV2.localMinter.selector,
            bytes4(keccak256("localMinter()"))
        );
        assertEq(
            ITokenMessengerV2.localMessageTransmitter.selector,
            bytes4(keccak256("localMessageTransmitter()"))
        );
        assertEq(
            ITokenMessengerV2.remoteTokenMessengers.selector,
            bytes4(keccak256("remoteTokenMessengers(uint32)"))
        );
        assertEq(
            ITokenMessengerV2.feeRecipient.selector,
            bytes4(keccak256("feeRecipient()"))
        );
        assertEq(
            ITokenMessengerV2.minFee.selector,
            bytes4(keccak256("minFee()"))
        );
        assertEq(
            ITokenMessengerV2.MIN_FEE_MULTIPLIER.selector,
            bytes4(keccak256("MIN_FEE_MULTIPLIER()"))
        );
    }

}
