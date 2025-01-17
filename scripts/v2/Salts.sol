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

// Salts used for CREATE2 deployments

bytes32 constant SALT_TOKEN_MINTER = keccak256("cctp.v2.tokenminter");
bytes32 constant SALT_TOKEN_MESSENGER = keccak256("cctp.v2.tokenmessenger");
bytes32 constant SALT_MESSAGE_TRANSMITTER = keccak256(
    "cctp.v2.messagetransmitter"
);
bytes32 constant SALT_ADDRESS_UTILS_EXTERNAL = keccak256(
    "cctp.v2.addressutilsexternal"
);
