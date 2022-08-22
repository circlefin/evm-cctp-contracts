/* SPDX-License-Identifier: UNLICENSED
 *
 * Copyright (c) 2022, Circle Internet Financial Trading Company Limited.
 * All rights reserved.
 *
 * Circle Internet Financial Trading Company Limited CONFIDENTIAL
 *
 * This file includes unpublished proprietary source code of Circle Internet
 * Financial Trading Company Limited, Inc. The copyright notice above does not
 * evidence any actual or intended publication of such source code. Disclosure
 * of this source code or any related proprietary information is strictly
 * prohibited without the express written permission of Circle Internet Financial
 * Trading Company Limited.
 */
pragma solidity ^0.7.6;

import "../src/messages/Message.sol";
import "../src/CircleMinter.sol";
import "./mocks/MockMintBurnToken.sol";
import "../lib/forge-std/src/Test.sol";

contract CircleMinterTest is Test {
    /**
     * @notice Emitted when a token pair is linked
     * @param localToken local token to support
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` corresponding to `localToken`
     */
    event TokenPairLinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a token pair is unlinked
     * @param localToken local token
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` unlinked from `localToken`
     */
    event TokenPairUnlinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a local token's enabled status is set
     * @param localToken Local token
     * @param enabled Enabled status (true for enabled, false for disabled.)
     */
    event LocalTokenEnabledStatusSet(address localToken, bool enabled);

    uint32 remoteDomain = 0;

    IMintBurnToken localToken;
    IMintBurnToken remoteToken;
    CircleMinter circleMinter;

    address localTokenAddress;
    bytes32 remoteTokenBytes32;
    address mintRecipientAddress;

    function setUp() public {
        circleMinter = new CircleMinter();
        localToken = new MockMintBurnToken();
        localTokenAddress = address(localToken);
        remoteToken = new MockMintBurnToken();
        remoteTokenBytes32 = Message.addressToBytes32(address(remoteToken));
        mintRecipientAddress = address(vm.addr(1506));
    }

    function testMint_succeeds(uint256 _amount) public {
        _mint(_amount);
    }

    function testMint_revertsOnUnsupportedMintToken(uint256 _amount) public {
        vm.expectRevert("Given mint token is not supported");
        circleMinter.mint(localTokenAddress, mintRecipientAddress, _amount);
    }

    function testBurn_succeeds() public {
        uint256 _amount = 100; // must be > 0

        _mint(_amount);

        // (Using an EOA here to simulate bridge contract. This will be a contract in bridge test suite.)
        address mockCircleBridge = vm.addr(1507);

        vm.prank(mintRecipientAddress);
        localToken.approve(address(mockCircleBridge), _amount);

        vm.prank(mockCircleBridge);
        localToken.transferFrom(
            mintRecipientAddress,
            address(circleMinter),
            _amount
        );

        circleMinter.burn(localTokenAddress, _amount);

        // assert balance and total supply decreased back to 0
        assertEq(localToken.balanceOf(mintRecipientAddress), 0);
        assertEq(localToken.totalSupply(), 0);
    }

    function testBurn_revertsOnUnsupportedBurnToken(uint256 _amount) public {
        vm.expectRevert("Given burn token is not supported");
        circleMinter.burn(localTokenAddress, _amount);
    }

    function testLinkTokenPair_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testLinkTokenPair_revertsOnAlreadyLinkedToken() public {
        _linkTokenPair(localTokenAddress);
        vm.expectRevert(
            "Unable to link token pair, remote token already linked to a local token"
        );
        circleMinter.linkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testUnlinkTokenPair_succeeds() public {
        _linkTokenPair(localTokenAddress);

        bytes32 remoteTokensKey = _hashRemoteDomainAndToken(
            remoteDomain,
            remoteTokenBytes32
        );
        assertEq(
            circleMinter.remoteTokensToLocalTokens(remoteTokensKey),
            localTokenAddress
        );

        circleMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );

        // reverts because there is no enabled local token for the given _remoteDomain, _remoteToken pair
        vm.expectRevert(
            "No enabled local token is associated with remote domain and token pair"
        );
        circleMinter.getEnabledLocalToken(remoteDomain, remoteTokenBytes32);
        assertEq(
            circleMinter.remoteTokensToLocalTokens(remoteTokensKey),
            address(0)
        );
    }

    function testUnlinkTokenPair_revertsOnAlreadyUnlinkedToken() public {
        vm.expectRevert(
            "Unable to unlink token pair, remote token is already not linked to any local token"
        );
        circleMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testGetLocalToken_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testGetEnabledLocalToken_revertsOnNotFoundMintToken() public {
        vm.expectRevert(
            "No enabled local token is associated with remote domain and token pair"
        );
        circleMinter.getEnabledLocalToken(remoteDomain, remoteTokenBytes32);
    }

    function testSetLocalTokenEnabledStatus(address _localToken) public {
        assertFalse(circleMinter.localTokens(_localToken));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenEnabledStatusSet(_localToken, true);
        circleMinter.setLocalTokenEnabledStatus(_localToken, true);
        assertTrue(circleMinter.localTokens(_localToken));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenEnabledStatusSet(_localToken, false);
        circleMinter.setLocalTokenEnabledStatus(_localToken, false);
        assertFalse(circleMinter.localTokens(_localToken));
    }

    function _linkTokenPair(
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteTokenBytes32
    ) internal {
        circleMinter.setLocalTokenEnabledStatus(_localToken, true);

        circleMinter.linkTokenPair(
            address(_localToken),
            _remoteDomain,
            _remoteTokenBytes32
        );

        address _actualLocalToken = circleMinter.getEnabledLocalToken(
            _remoteDomain,
            _remoteTokenBytes32
        );

        assertEq(_actualLocalToken, address(_localToken));
    }

    function _linkTokenPair(address _localToken) internal {
        _linkTokenPair(_localToken, remoteDomain, remoteTokenBytes32);
    }

    function _mint(uint256 _amount) internal {
        _linkTokenPair(localTokenAddress);

        // Assert balance of recipient and total supply is initially 0
        assertEq(localToken.balanceOf(mintRecipientAddress), 0);
        assertEq(localToken.totalSupply(), 0);

        circleMinter.mint(localTokenAddress, mintRecipientAddress, _amount);

        // Assert balance of recipient and total supply is incremented by mint amount
        assertEq(localToken.balanceOf(mintRecipientAddress), _amount);
        assertEq(localToken.totalSupply(), _amount);
    }

    /**
     * @notice hashes packed `_remoteDomain` and `_remoteToken`.
     * @param _remoteDomain Domain where message originated from
     * @param _remoteToken Address of remote token as bytes32
     * @return keccak hash of packed remote domain and token
     */
    function _hashRemoteDomainAndToken(
        uint32 _remoteDomain,
        bytes32 _remoteToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_remoteDomain, _remoteToken));
    }
}
