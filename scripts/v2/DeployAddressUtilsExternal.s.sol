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

import {Script} from "forge-std/Script.sol";
import {AddressUtilsExternal} from "../../src/messages/v2/AddressUtilsExternal.sol";
import {Create2Factory} from "../../src/v2/Create2Factory.sol";
import {SALT_ADDRESS_UTILS_EXTERNAL} from "./Salts.sol";

contract DeployAddressUtilsExternalScript is Script {
    Create2Factory private create2Factory;
    uint256 private create2FactoryOwnerKey;

    function deployAddressUtilsExternalScript()
        private
        returns (AddressUtilsExternal _addressUtilsExternal)
    {
        vm.startBroadcast(create2FactoryOwnerKey);
        _addressUtilsExternal = AddressUtilsExternal(
            create2Factory.deploy(
                0,
                SALT_ADDRESS_UTILS_EXTERNAL,
                type(AddressUtilsExternal).creationCode
            )
        );
        vm.stopBroadcast();
    }

    function setUp() public {
        create2Factory = Create2Factory(
            vm.envAddress("CREATE2_FACTORY_CONTRACT_ADDRESS")
        );
        create2FactoryOwnerKey = vm.envUint("CREATE2_FACTORY_OWNER_KEY");
    }

    function run() public {
        deployAddressUtilsExternalScript();
    }
}
