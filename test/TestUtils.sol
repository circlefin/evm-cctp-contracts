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
pragma abicoder v2;

import "../src/TokenMinter.sol";
import "../lib/forge-std/src/Test.sol";
import "./mocks/MockMintBurnToken.sol";
import {Denylistable} from "../src/roles/v2/Denylistable.sol";

contract TestUtils is Test {
    /**
     * @notice Emitted when a local TokenMessenger is added
     * @param localTokenMessenger address of local TokenMessenger
     * @notice Emitted when a local TokenMessenger is added
     */
    event LocalTokenMessengerAdded(address localTokenMessenger);

    /**
     * @notice Emitted when a local TokenMessenger is removed
     * @param localTokenMessenger address of local TokenMessenger
     * @notice Emitted when a local TokenMessenger is removed
     */
    event LocalTokenMessengerRemoved(address localTokenMessenger);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnershipTransferStarted(
        address indexed previousOwner,
        address indexed newOwner
    );

    event Pause();

    event Unpause();

    event PauserChanged(address indexed newAddress);

    event RescuerChanged(address indexed newRescuer);

    // test keys
    uint256 attesterPK = 1;
    uint256 fakeAttesterPK = 2;
    uint256 secondAttesterPK = 3;
    uint256 thirdAttesterPK = 4;
    uint256 destinationCallerPK = 5;
    uint256 recipientPK = 6;
    address attester = vm.addr(attesterPK);
    address secondAttester = vm.addr(secondAttesterPK);
    address thirdAttester = vm.addr(thirdAttesterPK);
    address fakeAttester = vm.addr(fakeAttesterPK);

    // test constants
    uint32 sourceDomain = 0;
    uint32 destinationDomain = 1;
    uint32 version = 0;
    uint32 nonce = 99;
    bytes32 sender;
    address recipientAddr = vm.addr(recipientPK);
    bytes32 recipient = Message.addressToBytes32(recipientAddr);
    address destinationCallerAddr = vm.addr(destinationCallerPK);
    bytes32 destinationCaller = Message.addressToBytes32(destinationCallerAddr);
    bytes32 emptyDestinationCaller = bytes32(0);
    bytes messageBody = bytes("test message");
    uint256 maxBurnAmountPerMessage = 1000000;
    address tokenController = vm.addr(1900);
    address newTokenController = vm.addr(1900);
    address owner = vm.addr(1902);
    address arbitraryAddress = vm.addr(1903);

    // See: https://github.com/foundry-rs/foundry/blob/2cdbfaca634b284084d0f86357623aef7a0d2ce3/crates/evm/core/src/constants.rs#L9
    // This address may be passed into fuzz tests by Foundry. VM.mockCalls fail when
    // specifying the cheat code address as the target.
    address foundryCheatCodeAddr = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    // 8 KiB
    uint32 maxMessageBodySize = 8 * 2 ** 10;
    // zero signature
    bytes zeroSignature =
        "00000000000000000000000000000000000000000000000000000000000000000";

    function linkTokenPair(
        TokenMinter tokenMinter,
        address _localToken,
        uint32 _remoteDomain,
        bytes32 _remoteTokenBytes32
    ) public {
        vm.prank(tokenController);
        tokenMinter.linkTokenPair(
            address(_localToken),
            _remoteDomain,
            _remoteTokenBytes32
        );

        address _actualLocalToken = tokenMinter.getLocalToken(
            _remoteDomain,
            _remoteTokenBytes32
        );

        assertEq(_actualLocalToken, address(_localToken));
    }

    function addLocalTokenMessenger(
        TokenMinter _tokenMinter,
        address _localTokenMessenger
    ) public {
        assertEq(_tokenMinter.localTokenMessenger(), address(0));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenMessengerAdded(_localTokenMessenger);
        _tokenMinter.addLocalTokenMessenger(_localTokenMessenger);

        assertEq(_tokenMinter.localTokenMessenger(), _localTokenMessenger);
    }

    function removeLocalTokenMessenger(TokenMinter _tokenMinter) public {
        address _currentTokenMessenger = _tokenMinter.localTokenMessenger();
        assertTrue(_currentTokenMessenger != address(0));

        vm.expectEmit(true, true, true, true);
        emit LocalTokenMessengerRemoved(_currentTokenMessenger);
        _tokenMinter.removeLocalTokenMessenger();

        assertEq(_tokenMinter.localTokenMessenger(), address(0));
    }

    function expectRevertWithWrongOwner() public {
        vm.prank(arbitraryAddress);
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function expectRevertWithWrongOwner(address wrongOwner) public {
        vm.prank(wrongOwner);
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function expectRevertWithWrongTokenController() public {
        vm.prank(arbitraryAddress);
        vm.expectRevert("Caller is not tokenController");
    }

    function assertContractIsRescuable(
        address _rescuableContractAddress,
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount,
        address _nonRescuer
    ) public {
        Rescuable _rescuableContract = Rescuable(_rescuableContractAddress);

        vm.assume(_rescuer != address(0));
        vm.assume(_rescueRecipient != address(0));
        vm.assume(_rescuer != _nonRescuer);
        vm.assume(_nonRescuer != _rescuableContract.owner());

        // Send erc20 to _rescuableContractAddress
        MockMintBurnToken _mockMintBurnToken = new MockMintBurnToken();

        // _rescueRecipient's initial balance of _mockMintBurnToken is 0
        assertEq(_mockMintBurnToken.balanceOf(_rescueRecipient), 0);

        // Mint _mockMintBurnToken to _rescueRecipient
        _mockMintBurnToken.mint(_rescueRecipient, _amount);

        // _rescueRecipient accidentally sends _mockMintBurnToken to the _rescuableContractAddress
        vm.prank(_rescueRecipient);
        _mockMintBurnToken.transfer(_rescuableContractAddress, _amount);
        assertEq(
            _mockMintBurnToken.balanceOf(_rescuableContractAddress),
            _amount
        );

        // Test updating the rescuer
        // (Updating rescuer to zero-address is not permitted)
        vm.prank(_rescuableContract.owner());
        vm.expectRevert("Rescuable: new rescuer is the zero address");
        _rescuableContract.updateRescuer(address(0));

        assertTrue(_rescuer != address(0));

        // Update rescuer to a valid address
        vm.expectEmit(true, true, true, true);
        emit RescuerChanged(_rescuer);
        vm.prank(_rescuableContract.owner());
        _rescuableContract.updateRescuer(_rescuer);

        // Rescue erc20 to _rescueRecipient
        vm.prank(_rescuer);
        _rescuableContract.rescueERC20(
            _mockMintBurnToken,
            _rescueRecipient,
            _amount
        );

        // Assert funds are rescued
        assertEq(_mockMintBurnToken.balanceOf(_rescueRecipient), _amount);

        // Check that non-rescuer address cannot rescue funds
        assertTrue(_rescuableContract.rescuer() != _nonRescuer);
        vm.prank(_nonRescuer);
        vm.expectRevert("Rescuable: caller is not the rescuer");
        _rescuableContract.rescueERC20(
            _mockMintBurnToken,
            _rescueRecipient,
            _amount
        );

        // Check that non-owner cannot update rescuer
        vm.prank(_nonRescuer);
        vm.expectRevert("Ownable: caller is not the owner");
        _rescuableContract.updateRescuer(_nonRescuer);
        vm.stopPrank();
    }

    function assertContractIsPausable(
        address _pausableContractAddress,
        address _currentPauser,
        address _newPauser,
        address _owner,
        address _nonOwner
    ) public {
        vm.assume(_newPauser != address(0));
        vm.assume(_owner != _nonOwner);
        vm.assume(_currentPauser != _newPauser);

        Pausable _pausableContract = Pausable(_pausableContractAddress);
        assertEq(_pausableContract.pauser(), _currentPauser);
        assertFalse(_pausableContract.paused());

        // Check that the current pauser can pause / unpause
        vm.startPrank(_currentPauser);

        vm.expectEmit(true, true, true, true);
        emit Pause();
        _pausableContract.pause();
        assertTrue(_pausableContract.paused());

        vm.expectEmit(true, true, true, true);
        emit Unpause();
        _pausableContract.unpause();
        assertFalse(_pausableContract.paused());

        vm.stopPrank();

        // Check that a non-pauser cannot pause / unpause
        assertTrue(_newPauser != _currentPauser);
        vm.startPrank(_newPauser);

        vm.expectRevert("Pausable: caller is not the pauser");
        _pausableContract.pause();

        vm.expectRevert("Pausable: caller is not the pauser");
        _pausableContract.unpause();

        vm.stopPrank();

        // Check that a non-owner cannot rotate the pauser
        assertTrue(_nonOwner != _owner);
        vm.prank(_nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        _pausableContract.updatePauser(_newPauser);
        vm.stopPrank();

        // Check that owner can rotate pauser, and it emits an event
        vm.expectEmit(true, true, true, true);
        emit PauserChanged(_newPauser);
        vm.prank(_owner);
        _pausableContract.updatePauser(_newPauser);

        assertEq(_pausableContract.pauser(), _newPauser);
    }

    function assertContractIsDenylistable(
        address _denylistableContract,
        address _randomAddress,
        address _newDenylister,
        address _nonOwner
    ) public {
        Denylistable _denylistable = Denylistable(_denylistableContract);
        address _owner = _denylistable.owner();

        vm.assume(_owner != _nonOwner);
        vm.assume(_newDenylister != address(0));
        vm.assume(_newDenylister != _randomAddress);

        // Test rotating denylister
        // Check only the owner can update the denylister
        vm.prank(_nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        _denylistable.updateDenylister(_newDenylister);

        // Rotate denylister
        vm.prank(_owner);
        _denylistable.updateDenylister(_newDenylister);
        assertEq(_denylistable.denylister(), _newDenylister);

        // Check adding and removing an address
        // First check that other addresses cannot add to the denylist
        assertTrue(_denylistable.denylister() != _randomAddress);
        vm.prank(_randomAddress);
        vm.expectRevert("Denylistable: caller is not denylister");
        _denylistable.denylist(_owner);

        // Now add
        assertFalse(_denylistable.isDenylisted(_randomAddress));
        vm.prank(_newDenylister);
        _denylistable.denylist(_randomAddress);
        assertTrue(_denylistable.isDenylisted(_randomAddress));

        // Now try to remove from the denylist, but as a different caller
        vm.prank(_randomAddress);
        vm.expectRevert("Denylistable: caller is not denylister");
        _denylistable.unDenylist(_randomAddress);

        // Now, actually remove
        vm.prank(_newDenylister);
        _denylistable.unDenylist(_randomAddress);
        assertFalse(_denylistable.isDenylisted(_randomAddress));
    }

    function transferOwnershipFailsIfNotOwner(
        address _ownableContractAddress,
        address _notOwner,
        address _newOwner
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address _initialOwner = _ownableContract.owner();
        expectRevertWithWrongOwner(_notOwner);
        _ownableContract.transferOwnership(_newOwner);

        // Sanity check
        assertEq(_initialOwner, _ownableContract.owner());
    }

    function acceptOwnershipFailsIfNotPendingOwner(
        address _ownableContractAddress,
        address _newOwner,
        address _otherAccount
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address _initialOwner = _ownableContract.owner();
        _ownableContract.transferOwnership(_newOwner);
        assertEq(_ownableContract.pendingOwner(), _newOwner);

        vm.prank(_otherAccount);
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        _ownableContract.acceptOwnership();

        // Sanity check
        assertEq(_initialOwner, _ownableContract.owner());
        assertEq(_newOwner, _ownableContract.pendingOwner());
    }

    function transferOwnership_revertsFromNonOwner(
        address _ownableContractAddress,
        address _newOwner,
        address _nonOwner
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address initialOwner = _ownableContract.owner();
        vm.assume(initialOwner != _nonOwner);
        vm.assume(initialOwner != _newOwner);
        vm.assume(_newOwner != _nonOwner);

        assertTrue(_nonOwner != initialOwner);

        // Test non-owner cannot transfer ownership
        vm.prank(_nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        _ownableContract.transferOwnership(_newOwner);
        vm.stopPrank();
    }

    function acceptOwnership_revertsFromNonPendingOwner(
        address _ownableContractAddress,
        address _newOwner,
        address _nonOwner
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address _initialOwner = _ownableContract.owner();
        vm.assume(_initialOwner != _nonOwner);
        vm.assume(_initialOwner != _newOwner);
        vm.assume(_newOwner != _nonOwner);

        // First, transfer ownership
        vm.prank(_initialOwner);
        _ownableContract.transferOwnership(_newOwner);
        vm.stopPrank();
        assertEq(_ownableContract.owner(), _initialOwner);
        assertEq(_ownableContract.pendingOwner(), _newOwner);

        // Test non-pending owner cannot acceptOwnership
        vm.prank(_nonOwner);
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        _ownableContract.acceptOwnership();
        vm.stopPrank();
    }

    function transferOwnershipAndAcceptOwnership(
        address _ownableContractAddress,
        address _newOwner
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address initialOwner = _ownableContract.owner();
        vm.assume(initialOwner != _newOwner);
        // assert that the owner is still unchanged
        assertEq(_ownableContract.owner(), initialOwner);

        // set pending owner
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferStarted(initialOwner, _newOwner);
        vm.prank(initialOwner);
        _ownableContract.transferOwnership(_newOwner);
        // assert that the owner is still unchanged, but pending owner is changed
        assertEq(_ownableContract.owner(), initialOwner);
        assertEq(_ownableContract.pendingOwner(), _newOwner);

        // accept ownership
        vm.prank(_newOwner);
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(initialOwner, _newOwner);
        _ownableContract.acceptOwnership();

        // assert that the owner is now _newOwner
        assertEq(_ownableContract.owner(), _newOwner);

        // sanity check owner changed
        assertFalse(_newOwner == initialOwner);
    }

    function transferOwnershipWithoutAcceptingThenTransferToNewOwner(
        address _ownableContractAddress,
        address _newOwner,
        address _secondNewOwner
    ) public {
        Ownable2Step _ownableContract = Ownable2Step(_ownableContractAddress);
        address initialOwner = _ownableContract.owner();
        vm.assume(_newOwner != address(0));
        vm.assume(
            _secondNewOwner != _newOwner &&
                _secondNewOwner != address(0) &&
                _secondNewOwner != _ownableContractAddress &&
                _secondNewOwner != initialOwner
        );
        assertEq(_ownableContract.owner(), initialOwner);

        // set pending owner
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferStarted(initialOwner, _newOwner);
        vm.prank(initialOwner);
        _ownableContract.transferOwnership(_newOwner);
        // assert that the owner is still unchanged, but pending owner is changed
        assertEq(_ownableContract.owner(), initialOwner);
        assertEq(_ownableContract.pendingOwner(), _newOwner);

        // change the owner again, because we realize _newOwner cannot accept ownership
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferStarted(initialOwner, _secondNewOwner);
        vm.prank(initialOwner);
        _ownableContract.transferOwnership(_secondNewOwner);

        // accept ownership
        vm.prank(_secondNewOwner);
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(initialOwner, _secondNewOwner);
        _ownableContract.acceptOwnership();

        // assert that the owner is now _secondNewOwner
        assertEq(_ownableContract.owner(), _secondNewOwner);
    }

    function _signMessageWithAttesterPK(
        bytes memory _message
    ) internal returns (bytes memory) {
        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        return _signMessage(_message, attesterPrivateKeys);
    }

    function _signMessage(
        bytes memory _message,
        uint256[] memory _privKeys
    ) internal returns (bytes memory) {
        bytes memory _signaturesConcatenated = "";

        for (uint256 i = 0; i < _privKeys.length; i++) {
            uint256 _privKey = _privKeys[i];
            bytes32 _digest = keccak256(_message);
            (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_privKey, _digest);
            bytes memory _signature = abi.encodePacked(_r, _s, _v);

            _signaturesConcatenated = abi.encodePacked(
                _signaturesConcatenated,
                _signature
            );
        }

        return _signaturesConcatenated;
    }
}
