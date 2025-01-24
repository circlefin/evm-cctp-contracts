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

import "forge-std/Script.sol";
import {Create2Factory} from "../src/v2/Create2Factory.sol";

contract DeployCreate2FactoryScript is Script {
    uint256 private create2FactoryDeployerKey;

    Create2Factory private create2Factory;

    function deployCreate2Factory(
        uint256 deployerKey
    ) internal returns (Create2Factory _create2Factory) {
        vm.startBroadcast(deployerKey);

        _create2Factory = new Create2Factory();

        vm.stopBroadcast();
    }

    function setUp() public {
        create2FactoryDeployerKey = vm.envUint("CREATE2_FACTORY_DEPLOYER_KEY");
    }

    function run() public {
        create2Factory = deployCreate2Factory(create2FactoryDeployerKey);
    }
}
