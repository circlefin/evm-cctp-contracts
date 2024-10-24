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

import {IReceiverV2} from "./IReceiverV2.sol";
import {IRelayerV2} from "./IRelayerV2.sol";

/**
 * @title IMessageTransmitterV2
 * @notice Interface for V2 message transmitters, which both relay and receive messages.
 */
interface IMessageTransmitterV2 is IRelayerV2, IReceiverV2 {

}
