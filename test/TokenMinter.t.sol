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
     * @param localToken local token address
     * @param remoteDomain remote domain
     * @param remoteToken token on `remoteDomain` unlinked from `localToken`
     */
    event TokenPairUnlinked(
        address localToken,
        uint32 remoteDomain,
        bytes32 remoteToken
    );

    /**
     * @notice Emitted when a burn limit per message is set for a particular token
     * @param token local token address
     * @param burnLimitPerMessage burn limit per message for `token`
     */
    event SetBurnLimitPerMessage(
        address indexed token,
        uint256 burnLimitPerMessage
    );

    /**
     * @notice Emitted when token controller is set
     * @param tokenController token controller address set
     */
    event SetTokenController(address tokenController);

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
        tokenMinter = new TokenMinter(tokenController);
        localToken = new MockMintBurnToken();
        localTokenAddress = address(localToken);
        remoteToken = new MockMintBurnToken();
        remoteTokenBytes32 = Message.addressToBytes32(address(remoteToken));
        tokenMinter.addLocalTokenMessenger(localTokenMessenger);
        tokenMinter.updatePauser(pauser);
    }

    function testMint_succeeds(uint256 _amount, address _localToken) public {
        _mint(_amount);
    }

    function testMint_revertsOnUnsupportedMintToken(uint256 _amount) public {
        vm.startPrank(localTokenMessenger);
        vm.expectRevert("Mint token not supported");
        tokenMinter.mint(
            sourceDomain,
            remoteTokenBytes32,
            mintRecipientAddress,
            _amount
        );
        vm.stopPrank();
    }

    function testMint_revertsIfCallerIsNotRegisteredTokenMessenger(
        uint256 _amount
    ) public {
        vm.prank(nonTokenMessenger);
        vm.expectRevert("Caller not local TokenMessenger");
        tokenMinter.mint(
            sourceDomain,
            remoteTokenBytes32,
            mintRecipientAddress,
            _amount
        );
    }

    function testMint_revertsWhenPaused(
        address _mintToken,
        address _to,
        uint256 _amount,
        bytes32 remoteToken
    ) public {
        vm.prank(pauser);
        tokenMinter.pause();
        vm.expectRevert("Pausable: paused");
        tokenMinter.mint(sourceDomain, remoteToken, _to, _amount);

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
        tokenMinter.mint(sourceDomain, remoteTokenBytes32, _to, _amount);
        vm.stopPrank();
    }

    function testBurn_succeeds(
        uint256 _amount,
        address _localToken,
        uint256 _allowedBurnAmount
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_allowedBurnAmount > 0 && _allowedBurnAmount >= _amount);

        vm.prank(tokenController);
        tokenMinter.setMaxBurnAmountPerMessage(
            localTokenAddress,
            _allowedBurnAmount
        );

        _mintAndBurn(_amount, _localToken);
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

    function testBurn_revertsWhenPaused() public {
        uint256 _allowedBurnAmount = 100;
        uint256 _burnAmount = 1;

        vm.prank(tokenController);
        tokenMinter.setMaxBurnAmountPerMessage(
            localTokenAddress,
            _allowedBurnAmount
        );

        vm.prank(pauser);
        tokenMinter.pause();
        vm.expectRevert("Pausable: paused");
        tokenMinter.burn(localTokenAddress, _burnAmount);

        // Mint works again after unpause
        vm.prank(pauser);
        tokenMinter.unpause();
        _mintAndBurn(_burnAmount, localTokenAddress);
    }

    function testBurn_revertsWhenAmountExceedsNonZeroBurnLimit(
        uint256 _allowedBurnAmount,
        uint256 _amount
    ) public {
        vm.assume(_allowedBurnAmount > 0);
        vm.assume(_amount > _allowedBurnAmount);

        vm.prank(tokenController);
        tokenMinter.setMaxBurnAmountPerMessage(
            localTokenAddress,
            _allowedBurnAmount
        );

        vm.expectRevert("Burn amount exceeds per tx limit");
        vm.startPrank(localTokenMessenger);
        tokenMinter.burn(localTokenAddress, _amount);
        vm.stopPrank();
    }

    function testBurn_revertsWhenBurnTokenNotSupported(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.expectRevert("Burn token not supported");
        vm.startPrank(localTokenMessenger);
        tokenMinter.burn(localTokenAddress, _amount);
        vm.stopPrank();
    }

    function testLinkTokenPair_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testLinkTokenPair_revertsOnAlreadyLinkedToken() public {
        _linkTokenPair(localTokenAddress);
        vm.expectRevert("Unable to link token pair");
        vm.prank(tokenController);
        tokenMinter.linkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testLinkTokenPair_revertsWhenCalledByNonOwner() public {
        expectRevertWithWrongTokenController();
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

        vm.prank(tokenController);
        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );

        address localTokenResultAfterUnlink = tokenMinter.getLocalToken(
            remoteDomain,
            remoteTokenBytes32
        );
        assertEq(localTokenResultAfterUnlink, address(0));
    }

    function testUnlinkTokenPair_revertsOnAlreadyUnlinkedToken() public {
        vm.prank(tokenController);
        vm.expectRevert("Unable to unlink token pair");
        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testUnlinkTokenPair_revertsWhenCalledByNonTokenController()
        public
    {
        expectRevertWithWrongTokenController();
        tokenMinter.unlinkTokenPair(
            address(localToken),
            remoteDomain,
            remoteTokenBytes32
        );
    }

    function testGetLocalToken_succeeds() public {
        _linkTokenPair(localTokenAddress);
    }

    function testGetLocalToken_findsNoLocalToken() public {
        address _result = tokenMinter.getLocalToken(
            remoteDomain,
            remoteTokenBytes32
        );
        assertEq(_result, address(0));
    }

    function testSetMaxBurnAmountPerMessage_succeeds(
        address _localToken,
        uint256 _burnLimitPerMessage
    ) public {
        vm.prank(tokenController);

        vm.expectEmit(true, true, true, true);
        emit SetBurnLimitPerMessage(_localToken, _burnLimitPerMessage);

        tokenMinter.setMaxBurnAmountPerMessage(
            _localToken,
            _burnLimitPerMessage
        );
    }

    function testSetMaxBurnAmountPerMessage_revertsWhenCalledByNonController(
        address _localToken,
        uint256 _burnLimitPerMessage
    ) public {
        expectRevertWithWrongTokenController();
        tokenMinter.setMaxBurnAmountPerMessage(
            _localToken,
            _burnLimitPerMessage
        );
    }

    function testSetTokenController_succeeds(address newTokenController)
        public
    {
        vm.assume(newTokenController != address(0));
        assertEq(tokenMinter.tokenController(), tokenController);

        vm.expectEmit(true, true, true, true);
        emit SetTokenController(newTokenController);
        tokenMinter.setTokenController(newTokenController);
        assertEq(tokenMinter.tokenController(), newTokenController);
    }

    function testSetTokenController_revertsWhenCalledByNonOwner(
        address _newTokenController
    ) public {
        expectRevertWithWrongOwner();
        tokenMinter.setTokenController(_newTokenController);
    }

    function testSetTokenController_revertsWhenCalledWithAddressZero() public {
        vm.expectRevert("Invalid token controller address");
        tokenMinter.setTokenController(address(0));
    }

    function testAddLocalTokenMessenger_succeeds() public {
        TokenMinter _tokenMinter = new TokenMinter(tokenController);
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
        TokenMinter _tokenMinter = new TokenMinter(tokenController);
        addLocalTokenMessenger(_tokenMinter, localTokenMessenger);
        removeLocalTokenMessenger(_tokenMinter);
    }

    function testRemoveLocalTokenMessenger_revertsWhenNoLocalTokenMessengerSet()
        public
    {
        TokenMinter _tokenMinter = new TokenMinter(tokenController);
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

    function testPausable(address _newPauser) public {
        assertContractIsPausable(
            address(tokenMinter),
            pauser,
            _newPauser,
            tokenMinter.owner()
        );
    }

    function testTransferOwnershipAndAcceptOwnership() public {
        address _newOwner = vm.addr(1509);
        transferOwnershipAndAcceptOwnership(address(tokenMinter), _newOwner);
    }

    function testTransferOwnershipWithoutAcceptingThenTransferToNewOwner(
        address _newOwner,
        address _secondNewOwner
    ) public {
        transferOwnershipWithoutAcceptingThenTransferToNewOwner(
            address(tokenMinter),
            _newOwner,
            _secondNewOwner
        );
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

        tokenMinter.mint(
            remoteDomain,
            remoteTokenBytes32,
            mintRecipientAddress,
            _amount
        );
        vm.stopPrank();

        // Assert balance of recipient and total supply is incremented by mint amount
        assertEq(localToken.balanceOf(mintRecipientAddress), _amount);
        assertEq(localToken.totalSupply(), _amount);
    }

    function _mintAndBurn(uint256 _amount, address _localToken) internal {
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
