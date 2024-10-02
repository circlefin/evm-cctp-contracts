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

import {TokenMinterTest} from "../TokenMinter.t.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {MockMintBurnToken} from "../mocks/MockMintBurnToken.sol";

contract TokenMinterV2Test is TokenMinterTest {
    // Test constant
    address account1 = address(123);
    address account2 = address(456);
    address account3 = address(789);

    // Overrides

    function createTokenMinter() internal override returns (address) {
        return address(new TokenMinterV2(tokenController));
    }

    // Tests

    function testMint_revertsWhenPaused(
        uint32 _sourceDomain,
        bytes32 _burnToken,
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.prank(pauser);
        tokenMinter.pause();
        // Sanity check
        assertTrue(tokenMinter.paused());

        vm.expectRevert("Pausable: paused");
        _getTokenMinterV2().mint(
            _sourceDomain,
            _burnToken,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsWhenNotCalledByLocalTokenMessenger(
        address _mockCaller,
        uint32 _sourceDomain,
        bytes32 _burnToken,
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.assume(_mockCaller != localTokenMessenger);

        vm.expectRevert("Caller not local TokenMessenger");
        vm.prank(_mockCaller);
        _getTokenMinterV2().mint(
            _sourceDomain,
            _burnToken,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfBurnTokenDoesntMatchRemoteDomain(
        bytes32 _burnToken,
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.assume(_burnToken != remoteTokenBytes32); // unrecognized burnToken for recognized remote domain

        vm.expectRevert("Mint token not supported");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            _burnToken,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfRemoteDomainDoesntMatchBurnToken(
        uint32 _remoteDomain,
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.assume(_remoteDomain != remoteDomain); // unrecognized domain for recognized burn token

        vm.expectRevert("Mint token not supported");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            _remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfNeitherRemoteDomainOrBurnTokenAreRecognized(
        uint32 _remoteDomain,
        bytes32 _burnToken,
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.assume(_remoteDomain != remoteDomain);
        vm.assume(_burnToken != remoteTokenBytes32);

        vm.expectRevert("Mint token not supported");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            _remoteDomain,
            _burnToken,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfFirstMintReverts(
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        _linkTokenPair(localTokenAddress);

        // Fail the 1st underlying mint()
        vm.mockCallRevert(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientOne,
                _amountOne
            ),
            "Testing - 1st mint failed"
        );

        vm.expectRevert("Testing - 1st mint failed");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfSecondMintReverts(
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        _linkTokenPair(localTokenAddress);

        // Fail the 2nd underlying mint()
        vm.mockCallRevert(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientTwo,
                _amountTwo
            ),
            "Testing - 2nd mint failed"
        );

        vm.expectRevert("Testing - 2nd mint failed");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfFirstMintReturnsFalse(
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        _linkTokenPair(localTokenAddress);

        // Return false from the 1st mint
        vm.mockCall(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientOne,
                _amountOne
            ),
            abi.encode(false)
        );

        vm.expectRevert("First mint operation failed");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_revertsIfSecondMintReturnsFalse(
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        _linkTokenPair(localTokenAddress);

        // Return false from the 2nd mint
        vm.mockCall(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientTwo,
                _amountTwo
            ),
            abi.encode(false)
        );

        vm.expectRevert("Second mint operation failed");
        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );
    }

    function testMint_succeeds(
        address _recipientOne,
        address _recipientTwo,
        uint256 _amountOne,
        uint256 _amountTwo
    ) public {
        vm.assume(type(uint256).max - _amountOne > _amountTwo);
        vm.assume(_recipientOne != _recipientTwo);

        _linkTokenPair(localTokenAddress);

        // Sanity check
        assertEq(localToken.balanceOf(_recipientOne), 0);
        assertEq(localToken.balanceOf(_recipientTwo), 0);

        vm.expectCall(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientOne,
                _amountOne
            ),
            1
        );

        vm.expectCall(
            localTokenAddress,
            abi.encodeWithSelector(
                MockMintBurnToken.mint.selector,
                _recipientTwo,
                _amountTwo
            ),
            1
        );

        vm.prank(localTokenMessenger);
        _getTokenMinterV2().mint(
            remoteDomain,
            remoteTokenBytes32,
            _recipientOne,
            _recipientTwo,
            _amountOne,
            _amountTwo
        );

        // Sanity check ending balances
        assertEq(localToken.balanceOf(_recipientOne), _amountOne);
        assertEq(localToken.balanceOf(_recipientTwo), _amountTwo);
    }

    // Test Helpers

    function _getTokenMinterV2() internal view returns (TokenMinterV2) {
        return TokenMinterV2(address(tokenMinter));
    }
}
