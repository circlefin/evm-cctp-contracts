/*
 * Copyright (c) 2022, Circle Internet Financial Limited.
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

import "../../lib/forge-std/src/Test.sol";
import "../../src/roles/Ownable2Step.sol";
import "../../src/TokenMinter.sol";

/**
 * @dev Negative unit tests of third party OZ contract, Ownable2Step.
 * (Positive tests for transferOwnership and acceptOwnership are covered in
 * MessageTransmitter.t.sol, TokenMessenger.t.sol, and TokenMinter.t.sol.)
 */
contract Ownable2StepTest is Test {
    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    address initialOwner = vm.addr(1505);

    Ownable2Step ownable;

    function setUp() public {
        // (arbitrary token controller param needed for instantiation)
        vm.prank(initialOwner);
        ownable = new TokenMinter(initialOwner);
        assertEq(ownable.owner(), initialOwner);
    }

    function testTransferOwnership_onlyOwner(address _wrongOwner) public {
        address _newOwner = vm.addr(1506);
        vm.assume(_wrongOwner != initialOwner);
        vm.prank(_wrongOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        ownable.transferOwnership(_newOwner);
    }

    function testAcceptOwnership_onlyNewOwner() public {
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        ownable.acceptOwnership();
    }
}
