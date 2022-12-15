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

import "forge-std/Test.sol";
import "../../src/messages/Message.sol";

contract MessageTest is Test {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;

    function testFormatMessage_fuzz(
        uint32 _version,
        uint32 _sourceDomain,
        uint32 _destinationDomain,
        uint64 _nonce,
        bytes32 _sender,
        bytes32 _recipient,
        bytes32 _destinationCaller,
        bytes memory _messageBody
    ) public {
        bytes memory message = Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        bytes29 _m = message.ref(0);
        assertEq(uint256(_m._version()), uint256(_version));
        assertEq(uint256(_m._sourceDomain()), uint256(_sourceDomain));
        assertEq(uint256(_m._destinationDomain()), uint256(_destinationDomain));
        assertEq(_m._nonce(), uint256(_nonce));
        assertEq(_m._sender(), _sender);
        assertEq(_m._recipient(), _recipient);
        assertEq(_m._destinationCaller(), _destinationCaller);
        assertEq(_m._messageBody().clone(), _messageBody);
    }

    function testFormatMessage() public {
        uint32 _version = 1;
        uint32 _sourceDomain = 1111;
        uint32 _destinationDomain = 1234;
        uint32 _nonce = 4294967295; // uint32 max value

        bytes32 _sender = bytes32(uint256(uint160(vm.addr(1505))));
        bytes32 _recipient = bytes32(uint256(uint160(vm.addr(1506))));
        bytes32 _destinationCaller = bytes32(uint256(uint160(vm.addr(1507))));
        bytes memory _messageBody = bytes("test message");

        bytes memory message = Message._formatMessage(
            _version,
            _sourceDomain,
            _destinationDomain,
            _nonce,
            _sender,
            _recipient,
            _destinationCaller,
            _messageBody
        );

        bytes29 _m = message.ref(0);
        assertEq(uint256(_m._version()), uint256(_version));
        assertEq(uint256(_m._sourceDomain()), uint256(_sourceDomain));
        assertEq(uint256(_m._destinationDomain()), uint256(_destinationDomain));
        assertEq(_m._sender(), _sender);
        assertEq(_m._recipient(), _recipient);
        assertEq(_m._messageBody().clone(), _messageBody);
        assertEq(uint256(_m._nonce()), uint256(_nonce));
    }

    function testAddressToBytes32ToAddress_fuzz(address _addr) public {
        bytes32 _bytes32FromAddr = Message.addressToBytes32(_addr);
        address _addrFromBytes32 = Message.bytes32ToAddress(_bytes32FromAddr);
        assertEq(_addrFromBytes32, _addr);
    }

    function testIsValidMessage_revertsForMalformedMessage() public {
        bytes29 _m = TypedMemView.nullView();
        vm.expectRevert("Malformed message");
        Message._validateMessageFormat(_m);
    }

    function testIsValidMessage_revertsForTooShortMessage() public {
        bytes memory _message = "foo";
        bytes29 _m = _message.ref(0);

        vm.expectRevert("Invalid message: too short");
        Message._validateMessageFormat(_m);
    }
}
