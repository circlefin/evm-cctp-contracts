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
import "../src/TokenMinter.sol";
import "./TestUtils.sol";
import "./mocks/MockMintBurnToken.sol";
import "../lib/forge-std/src/Test.sol";

contract TokenMinterTest is Test, TestUtils {
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
    TokenMinter tokenMinter;

    address localTokenAddress;
    bytes32 remoteTokenBytes32;
    address mintRecipientAddress = address(vm.addr(1506));
    address localTokenMessenger = address(vm.addr(1507));
    address nonTokenMessenger = address(vm.addr(1508));
    address pauser = vm.addr(1509);

    function setUp() public {
        tokenMinter = new TokenMinter();
        localToken = new MockMintBurnToken();
        localTokenAddress = address(localToken);
        remoteToken = new MockMintBurnToken();
        remoteTokenBytes32 = Message.addressToBytes32(address(remoteToken));
        tokenMinter.addLocalTokenMessenger(localTokenMessenger);
        tokenMinter.updatePauser(pauser);
    }

    function testMint_succeeds(uint256 _amount) public {
        _mint(_amount);
    }

    function testMint_revertsOnUnsupportedMintToken(uint256 _amount) public {
        vm.startPrank(localTokenMessenger);
        vm.expectRevert("Mint token not supported");
        tokenMinter.mint(localTokenAddress, mintRecipientAddress, _amount);
        vm.stopPrank();
    }

    function testMint_revertsIfCallerIsNotRegisteredTokenMessenger(
        uint256 _amount
    ) public {
        vm.prank(nonTokenMessenger);
        vm.expectRevert("Caller not local TokenMessenger");
        tokenMinter.mint(localTokenAddress, mintRecipientAddress, _amount);
    }

    function testMint_revertsWhenPaused(
        address _mintToken,
        address _to,
        uint256 _amount
    ) public {
        vm.prank(pauser);
        tokenMinter.pause();
        vm.expectRevert("Pausable: paused");
        tokenMinter.mint(_mintToken, _to, _amount);

        // Mint works again after unpause
        vm.prank(pauser);
        tokenMinter.unpause();
        _mint(_amount);
    }

    function testMint_revertsOnFailedTokenMint(address _to, uint256 _amount)
        public
    {
        _linkTokenPair(localTokenAddress);
        vm.mockCall(
            localTokenAddress,
            abi.encodeWithSelector(MockMintBurnToken.mint.selector),
            abi.encode(false)
        );
        vm.startPrank(localTokenMessenger);
        vm.expectRevert("Mint operation failed");
        tokenMinter.mint(localTokenAddress, _to, _amount);
        vm.stopPrank();
    }

    function testBurn_succeeds(uint256 _amount) public {
        vm.assume(_amount > 0);
        _mintAndBurn(_amount);
    }

    function testBurn_revertsOnUnsupportedBurnToken(uint256 _amount) public {
        vm.startPrank(localTokenMessenger);
        vm.expectRevert("Burn token not supported");
        tokenMinter.burn(localTokenAddress, _amount);
        vm.stopPrank();
    }

    function testBurn_revertsIfCallerIsNotRegisteredTokenMessenger(
        uint256 _amount,
        address _remoteToken
    ) public {
        vm.prank(nonTokenMessenger);
        vm.expectRevert("Caller not local TokenMessenger");
        tokenMinter.burn(_remoteToken, _amount);
    }

    function testBurn_revertsWhenPaused(address _remoteToken, uint256 _amount)
        public
    {
        vm.assume(_amount > 0);

        vm.prank(pauser);
        tokenMinter.pause();
        vm.expectRevert("Pausable: paused");
        tokenMinter.burn(_remoteToken, _amount);

        // Mint works again after unpause
        vm.prank(pauser);
        tokenMinter.unpause();
        _mintAndBurn(_amount);
    }

    function testLinkTokenPair_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testLinkTokenPair_revertsOnAlreadyLinkedToken() public {
        _linkTokenPair(localTokenAddress);
        vm.expectRevert("Unable to link token pair");
        tokenMinter.linkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testLinkTokenPair_revertsWhenCalledByNonOwner() public {
        expectRevertWithWrongOwner();
        tokenMinter.linkTokenPair(
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
            tokenMinter.remoteTokensToLocalTokens(remoteTokensKey),
            localTokenAddress
        );

        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );

        // reverts because there is no enabled local token for the given _remoteDomain, _remoteToken pair
        vm.expectRevert("Local token not enabled");
        tokenMinter.getEnabledLocalToken(remoteDomain, remoteTokenBytes32);
        assertEq(
            tokenMinter.remoteTokensToLocalTokens(remoteTokensKey),
            address(0)
        );
    }

    function testUnlinkTokenPair_revertsOnAlreadyUnlinkedToken() public {
        vm.expectRevert("Unable to unlink token pair");
        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testUnlinkTokenPair_revertsWhenCalledByNonOwner() public {
        expectRevertWithWrongOwner();
        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testGetLocalToken_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testGetEnabledLocalToken_revertsOnNotFoundMintToken() public {
        vm.expectRevert("Local token not enabled");
        tokenMinter.getEnabledLocalToken(remoteDomain, remoteTokenBytes32);
    }

    function testSetLocalTokenEnabledStatus(address _localToken) public {
        assertFalse(tokenMinter.localTokens(_localToken));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenEnabledStatusSet(_localToken, true);
        tokenMinter.setLocalTokenEnabledStatus(_localToken, true);
        assertTrue(tokenMinter.localTokens(_localToken));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenEnabledStatusSet(_localToken, false);
        tokenMinter.setLocalTokenEnabledStatus(_localToken, false);
        assertFalse(tokenMinter.localTokens(_localToken));
    }

    function testSetLocalTokenEnabledStatus_revertsWhenCalledByNonOwner()
        public
    {
        expectRevertWithWrongOwner();
        tokenMinter.setLocalTokenEnabledStatus(address(localToken), false);
    }

    function testAddLocalTokenMessenger_succeeds() public {
        TokenMinter _tokenMinter = new TokenMinter();
        addLocalTokenMessenger(_tokenMinter, localTokenMessenger);
    }

    function testAddLocalTokenMessenger_revertsWhenLocalTokenMinterAlreadySet()
        public
    {
        address _tokenMessenger = vm.addr(1700);
        vm.expectRevert("Local TokenMessenger already set");
        tokenMinter.addLocalTokenMessenger(_tokenMessenger);
    }

    function testAddLocalTokenMessenger_revertsWhenNewTokenMessengerIsZeroAddress()
        public
    {
        vm.expectRevert("Invalid TokenMessenger address");
        tokenMinter.addLocalTokenMessenger(address(0));
    }

    function testAddLocalTokenMessenger_revertsWhenCalledByNonOwner(
        address _tokenMessenger
    ) public {
        expectRevertWithWrongOwner();
        tokenMinter.addLocalTokenMessenger(_tokenMessenger);
    }

    function testRemoveLocalTokenMessenger_succeeds() public {
        TokenMinter _tokenMinter = new TokenMinter();
        addLocalTokenMessenger(_tokenMinter, localTokenMessenger);
        removeLocalTokenMessenger(_tokenMinter);
    }

    function testRemoveLocalTokenMessenger_revertsWhenNoLocalTokenMessengerSet()
        public
    {
        TokenMinter _tokenMinter = new TokenMinter();
        vm.expectRevert("No local TokenMessenger is set");
        _tokenMinter.removeLocalTokenMessenger();
    }

    function testRemoveLocalTokenMessenger_revertsWhenCalledByNonOwner()
        public
    {
        expectRevertWithWrongOwner();
        tokenMinter.removeLocalTokenMessenger();
    }

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount
    ) public {
        assertContractIsRescuable(
            address(tokenMinter),
            _rescuer,
            _rescueRecipient,
            _amount
        );
    }

    function testTransferOwnership() public {
        address _newOwner = vm.addr(1509);
        transferOwnership(address(tokenMinter), _newOwner);
    }

    function _linkTokenPair(address _localToken) internal {
        linkTokenPair(
            tokenMinter,
            _localToken,
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function _mint(uint256 _amount) internal {
        _linkTokenPair(localTokenAddress);

        // Assert balance of recipient and total supply is initially 0
        assertEq(localToken.balanceOf(mintRecipientAddress), 0);
        assertEq(localToken.totalSupply(), 0);

        vm.startPrank(localTokenMessenger);
        tokenMinter.mint(localTokenAddress, mintRecipientAddress, _amount);
        vm.stopPrank();

        // Assert balance of recipient and total supply is incremented by mint amount
        assertEq(localToken.balanceOf(mintRecipientAddress), _amount);
        assertEq(localToken.totalSupply(), _amount);
    }

    function _mintAndBurn(uint256 _amount) internal {
        _mint(_amount);

        address mockTokenMessenger = vm.addr(1507);

        vm.prank(mintRecipientAddress);
        localToken.approve(address(mockTokenMessenger), _amount);

        vm.prank(mockTokenMessenger);
        localToken.transferFrom(
            mintRecipientAddress,
            address(tokenMinter),
            _amount
        );

        vm.startPrank(localTokenMessenger);
        tokenMinter.burn(localTokenAddress, _amount);
        vm.stopPrank();

        // assert balance and total supply decreased back to 0
        assertEq(localToken.balanceOf(mintRecipientAddress), 0);
        assertEq(localToken.totalSupply(), 0);
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
