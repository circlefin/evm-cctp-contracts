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

import "../lib/forge-std/src/Test.sol";
import "../src/CircleBridge.sol";
import "../src/messages/Message.sol";
import "../src/messages/BurnMessage.sol";
import "../src/MessageTransmitter.sol";
import "../src/CircleMinter.sol";
import "./mocks/MockMintBurnToken.sol";
import "./mocks/MockRelayer.sol";
import "./TestUtils.sol";

contract CircleBridgeTest is Test, TestUtils {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessage for bytes29;

    // Events
    /**
     * @notice Emitted when a remote CircleBridge is added
     * @param _domain remote domain
     * @param _circleBridge CircleBridge on remote domain
     */
    event RemoteCircleBridgeAdded(uint32 _domain, bytes32 _circleBridge);

    /**
     * @notice Emitted when a remote CircleBridge is removed
     * @param _domain remote domain
     * @param _circleBridge CircleBridge on remote domain
     */
    event RemoteCircleBridgeRemoved(uint32 _domain, bytes32 _circleBridge);

    /**
     * @notice Emitted when a local minter is added
     * @param _localMinter address of local minter
     * @notice Emitted when a local minter is added
     */
    event LocalMinterAdded(address _localMinter);

    /**
     * @notice Emitted when a local minter is removed
     * @param _localMinter address of local minter
     * @notice Emitted when a local minter is removed
     */
    event LocalMinterRemoved(address _localMinter);

    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when a deposit for burn is received on source domain
     * @param depositor address where deposit is transferred from
     * @param burnToken address of token burnt on source domain
     * @param amount deposit amount
     * @param mintRecipient address receiving minted tokens on destination domain as bytes32
     * @param remoteDomain destination domain
     * @param circleMessenger address of Circle Messenger on destination domain as bytes32
     */
    event DepositForBurn(
        address depositor,
        address burnToken,
        uint256 amount,
        bytes32 mintRecipient,
        uint32 remoteDomain,
        bytes32 circleMessenger
    );

    /**
     * @notice Emitted when tokens are minted
     * @param _mintRecipient recipient address of minted tokens
     * @param _amount amount of minted tokens
     * @param _mintToken contract address of minted token
     */
    event MintAndWithdraw(
        address _mintRecipient,
        uint256 _amount,
        address _mintToken
    );

    // Constants
    uint32 localDomain = 0;
    uint32 version = 0;
    uint32 remoteDomain = 1;
    bytes32 remoteCircleBridge;
    address owner = vm.addr(1506);
    uint32 maxMessageBodySize = 8 * 2**10;
    uint256 attesterPK = 1;
    address attester = vm.addr(attesterPK);
    uint32 messageBodyVersion = 1;

    CircleBridge localCircleBridge;
    CircleBridge destCircleBridge;
    MessageTransmitter localMessageTransmitter =
        new MessageTransmitter(
            localDomain,
            attester,
            maxMessageBodySize,
            version
        );
    MessageTransmitter remoteMessageTransmitter =
        new MessageTransmitter(
            remoteDomain,
            attester,
            maxMessageBodySize,
            version
        );
    MockMintBurnToken localToken = new MockMintBurnToken();
    MockMintBurnToken destToken = new MockMintBurnToken();
    CircleMinter localCircleMinter = new CircleMinter();
    CircleMinter destCircleMinter = new CircleMinter();

    function setUp() public {
        localCircleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );

        linkTokenPair(
            localCircleMinter,
            address(localToken),
            remoteDomain,
            remoteCircleBridge
        );

        linkTokenPair(
            destCircleMinter,
            address(destToken),
            localDomain,
            Message.addressToBytes32(address(localToken))
        );

        localCircleBridge.addLocalMinter(address(localCircleMinter));

        destCircleBridge = new CircleBridge(
            address(remoteMessageTransmitter),
            messageBodyVersion
        );

        remoteCircleBridge = Message.addressToBytes32(
            address(destCircleBridge)
        );

        localCircleBridge.addRemoteCircleBridge(
            remoteDomain,
            remoteCircleBridge
        );

        destCircleBridge.addLocalMinter(address(destCircleMinter));

        destCircleBridge.addRemoteCircleBridge(
            localDomain,
            Message.addressToBytes32(address(localCircleBridge))
        );

        localCircleMinter.addLocalCircleBridge(address(localCircleBridge));
        destCircleMinter.addLocalCircleBridge(address(destCircleBridge));
    }

    function testDepositForBurn_revertsIfNoRemoteCircleBridgeExistsForDomain()
        public
    {
        uint256 _amount = 5;
        bytes32 _mintRecipient = Message.addressToBytes32(vm.addr(1505));

        MockRelayer _mockRelayer = new MockRelayer();
        address _mockRelayerAddress = address(_mockRelayer);
        CircleBridge _circleBridge = new CircleBridge(
            _mockRelayerAddress,
            messageBodyVersion
        );

        vm.expectRevert("Remote CircleBridge does not exist for domain");
        _circleBridge.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            address(localToken)
        );
    }

    function testDepositForBurn_revertsIfLocalMinterIsNotSet(
        uint256 _amount,
        bytes32 _mintRecipient
    ) public {
        CircleBridge _circleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );

        _circleBridge.addRemoteCircleBridge(remoteDomain, remoteCircleBridge);

        vm.expectRevert("Local minter is not set");
        _circleBridge.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            address(localToken)
        );
    }

    function testDepositForBurn_revertsIfTransferAmountIsZero() public {
        uint256 _amount = 0;

        vm.expectRevert("MockMintBurnToken: burn amount not greater than 0");
        localCircleBridge.depositForBurn(
            _amount,
            remoteDomain,
            remoteCircleBridge,
            address(localToken)
        );
    }

    function testDepositForBurn_revertsIfTransferAmountExceedsAllowance()
        public
    {
        uint256 _amount = 1;

        // Fails because approve() was never called, allowance is 0.
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        localCircleBridge.depositForBurn(
            _amount,
            remoteDomain,
            remoteCircleBridge,
            address(localToken)
        );
    }

    function testDepositForBurn_revertsTransferringInsufficientFunds() public {
        uint256 _amount = 5;
        address _spender = address(localCircleBridge);

        localToken.mint(owner, 1);

        vm.prank(owner);
        localToken.approve(_spender, 10);

        vm.prank(owner);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        localCircleBridge.depositForBurn(
            _amount,
            remoteDomain,
            remoteCircleBridge,
            address(localToken)
        );
    }

    function testDepositForBurn_revertsIfRelayerReturnsFalse() public {
        uint256 _amount = 5;
        bytes32 _mintRecipient = Message.addressToBytes32(vm.addr(1505));

        MockRelayer _mockRelayer = new MockRelayer();
        address _mockRelayerAddress = address(_mockRelayer);
        CircleBridge _circleBridge = new CircleBridge(
            _mockRelayerAddress,
            messageBodyVersion
        );

        _circleBridge.addLocalMinter(address(localCircleMinter));
        localCircleMinter.removeLocalCircleBridge();
        localCircleMinter.addLocalCircleBridge(address(_circleBridge));
        _circleBridge.addRemoteCircleBridge(remoteDomain, remoteCircleBridge);

        localToken.mint(owner, 10);

        vm.prank(owner);
        localToken.approve(address(_circleBridge), 10);

        vm.prank(owner);
        vm.expectRevert("MessageTransmitter sendMessage() returned false");
        _circleBridge.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            address(localToken)
        );
    }

    function testDepositForBurn_succeeds() public {
        uint256 _amount = 5;
        address _mintRecipientAddr = vm.addr(1505);

        _depositForBurn(_mintRecipientAddr, _amount);
    }

    // TODO [STABLE-926] test mint fails due to insufficient mintAllowance

    function testHandleReceiveMessage_succeedsForMint() public {
        address _mintRecipientAddr = vm.addr(1505);
        uint256 _amount = 5;
        bytes memory _messageBody = _depositForBurn(
            _mintRecipientAddr,
            _amount
        );

        // assert balance of recipient is initially 0
        assertEq(destToken.balanceOf(_mintRecipientAddr), 0);

        // test event is emitted
        vm.expectEmit(true, true, true, true);
        emit MintAndWithdraw(_mintRecipientAddr, _amount, address(destToken));

        vm.startPrank(address(remoteMessageTransmitter));
        assertTrue(
            destCircleBridge.handleReceiveMessage(
                localDomain,
                Message.addressToBytes32(address(localCircleBridge)),
                _messageBody
            )
        );
        vm.stopPrank();

        // assert balance of recipient is incremented by mint amount
        assertEq(destToken.balanceOf(_mintRecipientAddr), _amount);
    }

    function testHandleReceiveMessage_failsIfRecipientIsNotRemoteCircleBridge()
        public
    {
        bytes memory _messageBody = bytes("foo");
        bytes32 _address = Message.addressToBytes32(address(vm.addr(1)));

        vm.startPrank(address(remoteMessageTransmitter));
        vm.expectRevert("Remote Circle Bridge is not supported");
        destCircleBridge.handleReceiveMessage(
            localDomain,
            _address,
            _messageBody
        );

        vm.stopPrank();
    }

    function testHandleReceiveMessage_failsIfSenderIsNotLocalMessageTransmitter()
        public
    {
        bytes memory _messageBody = bytes("foo");
        bytes32 _address = Message.addressToBytes32(address(vm.addr(1)));

        vm.expectRevert(
            "Caller is not the registered message transmitter for this domain"
        );
        localCircleBridge.handleReceiveMessage(
            localDomain,
            _address,
            _messageBody
        );
    }

    function testHandleReceiveMessage_revertsIfNoLocalMinterIsSet(
        bytes32 _mintRecipient,
        uint256 _amount
    ) public {
        bytes memory _messageBody = BurnMessage.formatMessage(
            messageBodyVersion,
            Message.addressToBytes32(address(localToken)),
            _mintRecipient,
            _amount
        );

        destCircleBridge.removeLocalMinter();
        bytes32 _localCircleBridge = Message.addressToBytes32(
            address(localCircleBridge)
        );
        vm.startPrank(address(remoteMessageTransmitter));
        vm.expectRevert("Local minter is not set");
        destCircleBridge.handleReceiveMessage(
            localDomain,
            _localCircleBridge,
            _messageBody
        );
        vm.stopPrank();
    }

    function testHandleReceiveMessage_revertsIfNoEnabledLocalTokenSet(
        bytes32 _localToken,
        bytes32 _mintRecipient,
        uint256 _amount
    ) public {
        bytes memory _messageBody = BurnMessage.formatMessage(
            messageBodyVersion,
            _localToken,
            _mintRecipient,
            _amount
        );

        bytes32 _localCircleBridge = Message.addressToBytes32(
            address(localCircleBridge)
        );
        vm.startPrank(address(remoteMessageTransmitter));
        vm.expectRevert(
            "No enabled local token is associated with remote domain and token pair"
        );
        destCircleBridge.handleReceiveMessage(
            localDomain,
            _localCircleBridge,
            _messageBody
        );
        vm.stopPrank();
    }

    function testHandleReceiveMessage_revertsOnInvalidMessage() public {
        uint256 _amount = 5;
        bytes32 _mintRecipient = Message.addressToBytes32(vm.addr(1505));

        bytes32 localTokenAddressBytes32 = Message.addressToBytes32(
            address(localToken)
        );

        // Format message body
        bytes memory _messageBody = abi.encodePacked(
            uint256(1),
            localTokenAddressBytes32,
            _mintRecipient,
            _amount
        );

        bytes32 _address = Message.addressToBytes32(address(vm.addr(1)));
        bytes32 _localCircleBridge = Message.addressToBytes32(
            address(localCircleBridge)
        );

        vm.startPrank(address(remoteMessageTransmitter));
        vm.expectRevert("Invalid message");
        destCircleBridge.handleReceiveMessage(
            localDomain,
            _localCircleBridge,
            _messageBody
        );
        vm.stopPrank();
    }

    function testAddRemoteCircleBridge_succeeds(uint32 _domain) public {
        CircleBridge _circleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );

        assertEq(_circleBridge.remoteCircleBridges(_domain), bytes32(0));

        vm.expectEmit(true, true, true, true);
        emit RemoteCircleBridgeAdded(_domain, remoteCircleBridge);
        _circleBridge.addRemoteCircleBridge(_domain, remoteCircleBridge);

        assertEq(
            _circleBridge.remoteCircleBridges(_domain),
            remoteCircleBridge
        );
    }

    function testAddRemoteCircleBridge_revertsOnExistingRemoteCircleBridge()
        public
    {
        assertEq(
            localCircleBridge.remoteCircleBridges(remoteDomain),
            remoteCircleBridge
        );

        vm.expectRevert("CircleBridge already set for given remote domain.");
        localCircleBridge.addRemoteCircleBridge(
            remoteDomain,
            remoteCircleBridge
        );

        // original destination router is still registered
        assertEq(
            localCircleBridge.remoteCircleBridges(remoteDomain),
            remoteCircleBridge
        );
    }

    function testAddRemoteCircleBridge_revertsOnNonOwner(
        uint32 _domain,
        bytes32 _circleBridge
    ) public {
        expectRevertWithWrongOwner();
        localCircleBridge.addRemoteCircleBridge(_domain, _circleBridge);
    }

    function testRemoveRemoteCircleBridge_succeeds() public {
        uint32 _remoteDomain = 100;
        bytes32 _remoteCircleBridge = Message.addressToBytes32(vm.addr(1));

        localCircleBridge.addRemoteCircleBridge(
            _remoteDomain,
            _remoteCircleBridge
        );

        vm.expectEmit(true, true, true, true);
        emit RemoteCircleBridgeRemoved(_remoteDomain, _remoteCircleBridge);
        localCircleBridge.removeRemoteCircleBridge(
            _remoteDomain,
            _remoteCircleBridge
        );
    }

    function testRemoveRemoteCircleBridge_revertsOnNoCircleBridgeSet() public {
        uint32 _remoteDomain = 100;
        bytes32 _remoteCircleBridge = Message.addressToBytes32(vm.addr(1));

        vm.expectRevert("No CircleBridge set for given remote domain.");
        localCircleBridge.removeRemoteCircleBridge(
            _remoteDomain,
            _remoteCircleBridge
        );
    }

    function testRemoveRemoteCircleBridge_revertsOnNonOwner(
        uint32 _domain,
        bytes32 _circleBridge
    ) public {
        expectRevertWithWrongOwner();
        localCircleBridge.removeRemoteCircleBridge(_domain, _circleBridge);
    }

    function testAddLocalMinter_succeeds(address _localMinter) public {
        CircleBridge _circleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );
        _addLocalMinter(_localMinter, _circleBridge);
    }

    function testAddLocalMinter_revertsIfAlreadySet(address _address) public {
        vm.expectRevert("Local minter is already set.");
        localCircleBridge.addLocalMinter(_address);
    }

    function testAddLocalMinter_revertsOnNonOwner(address _localMinter) public {
        expectRevertWithWrongOwner();
        localCircleBridge.addLocalMinter(_localMinter);
    }

    function testRemoveLocalMinter_succeeds() public {
        address _localMinter = vm.addr(1);
        CircleBridge _circleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );
        _addLocalMinter(_localMinter, _circleBridge);

        vm.expectEmit(true, true, true, true);
        emit LocalMinterRemoved(_localMinter);
        _circleBridge.removeLocalMinter();
    }

    function testRemoveLocalMinter_revertsIfNoLocalMinterSet() public {
        CircleBridge _circleBridge = new CircleBridge(
            address(localMessageTransmitter),
            messageBodyVersion
        );
        vm.expectRevert("No local minter is set.");
        _circleBridge.removeLocalMinter();
    }

    function testRemoveLocalMinter_revertsOnNonOwner() public {
        expectRevertWithWrongOwner();
        localCircleBridge.removeLocalMinter();
    }

    function testRescuable(
        address _rescuer,
        address _rescueRecipient,
        uint256 _amount
    ) public {
        assertContractIsRescuable(
            address(localCircleBridge),
            _rescuer,
            _rescueRecipient,
            _amount
        );
    }

    function testTransferOwnership() public {
        address _newOwner = vm.addr(1509);
        transferOwnership(address(localCircleBridge), _newOwner);
    }

    function _addLocalMinter(address _localMinter, CircleBridge _circleBridge)
        internal
    {
        vm.expectEmit(true, true, true, true);
        emit LocalMinterAdded(_localMinter);
        _circleBridge.addLocalMinter(_localMinter);
    }

    function _depositForBurn(address _mintRecipientAddr, uint256 _amount)
        internal
        returns (bytes memory)
    {
        address _spender = address(localCircleBridge);
        bytes32 _mintRecipient = Message.addressToBytes32(_mintRecipientAddr);

        localToken.mint(owner, 10);

        vm.prank(owner);
        localToken.approve(_spender, 10);

        bytes32 localTokenAddressBytes32 = Message.addressToBytes32(
            address(localToken)
        );

        // Format message body
        bytes memory _messageBody = BurnMessage.formatMessage(
            messageBodyVersion,
            localTokenAddressBytes32,
            _mintRecipient,
            _amount
        );

        // assert that a MessageSent event was logged with expected message bytes
        uint64 _nonce = localMessageTransmitter.availableNonces(remoteDomain);

        bytes memory _expectedMessage = Message.formatMessage(
            version,
            localDomain,
            remoteDomain,
            _nonce,
            Message.addressToBytes32(address(localCircleBridge)),
            remoteCircleBridge,
            _messageBody
        );

        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit DepositForBurn(
            owner,
            address(localToken),
            _amount,
            _mintRecipient,
            remoteDomain,
            remoteCircleBridge
        );

        vm.prank(owner);
        assertTrue(
            localCircleBridge.depositForBurn(
                _amount,
                remoteDomain,
                _mintRecipient,
                address(localToken)
            )
        );

        // deserialize _messageBody
        bytes29 _m = _messageBody.ref(0);
        assertEq(
            _m.getBurnToken(),
            Message.addressToBytes32(address(localToken))
        );
        assertEq(_m.getMintRecipient(), _mintRecipient);
        assertEq(_m.getBurnToken(), localTokenAddressBytes32);
        assertEq(_m.getAmount(), _amount);

        return _messageBody;
    }
}
