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

import {BaseTokenMessengerTest} from "./BaseTokenMessenger.t.sol";
import {TokenMessengerV2} from "../../src/v2/TokenMessengerV2.sol";
import {AddressUtils} from "../../src/messages/v2/AddressUtils.sol";
import {MockMintBurnToken} from "../mocks/MockMintBurnToken.sol";
import {TokenMinterV2} from "../../src/v2/TokenMinterV2.sol";
import {TokenMinter} from "../../src/TokenMinter.sol";
import {MessageTransmitterV2} from "../../src/v2/MessageTransmitterV2.sol";
import {BurnMessageV2} from "../../src/messages/v2/BurnMessageV2.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {AdminUpgradableProxy} from "../../src/proxy/AdminUpgradableProxy.sol";
import {MockTokenMessengerV3} from "../mocks/v2/MockTokenMessengerV3.sol";
import {TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD, FINALITY_THRESHOLD_FINALIZED, FINALITY_THRESHOLD_CONFIRMED} from "../../src/v2/FinalityThresholds.sol";

contract TokenMessengerV2Test is BaseTokenMessengerTest {
    // Events
    event DepositForBurn(
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 indexed minFinalityThreshold,
        bytes hookData
    );

    event MintAndWithdraw(
        address indexed mintRecipient,
        uint256 amount,
        address indexed mintToken,
        uint256 feeCollected
    );

    event Upgraded(address indexed implementation);

    event DenylisterChanged(
        address indexed oldDenylister,
        address indexed newDenylister
    );

    // Libraries
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BurnMessageV2 for bytes29;
    using AddressUtils for address;
    using AddressUtils for bytes32;

    // Constants
    uint32 remoteDomain = 1;
    uint32 messageBodyVersion = 2;

    address localMessageTransmitter = address(10);
    address remoteMessageTransmitter = address(20);

    TokenMessengerV2 localTokenMessenger;
    TokenMessengerV2 tokenMessengerImpl;

    address remoteTokenMessenger = address(30);
    bytes32 remoteTokenMessengerAddr;

    address remoteTokenAddr = address(40);

    // TokenMessengerV2 Roles
    address feeRecipient = address(50);
    address denylister = address(60);
    address proxyAdmin = address(70);
    address rescuer = address(80);

    MockMintBurnToken localToken = new MockMintBurnToken();
    TokenMinterV2 localTokenMinter = new TokenMinterV2(tokenController);

    function setUp() public override {
        // Deploy implementation
        tokenMessengerImpl = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        // Deploy and initialize proxy
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        remoteTokenMessengerAddr = remoteTokenMessenger.toBytes32();

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
        localTokenMessenger = TokenMessengerV2(address(_proxy));

        linkTokenPair(
            localTokenMinter,
            address(localToken),
            remoteDomain,
            remoteTokenAddr.toBytes32()
        );

        localTokenMinter.addLocalTokenMessenger(address(localTokenMessenger));

        super.setUp();
    }

    // BaseTokenMessengerTest overrides

    function setUpBaseTokenMessenger() internal override returns (address) {
        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );
        return address(_tokenMessenger);
    }

    function createBaseTokenMessenger(
        address _localMessageTransmitter,
        uint32 _messageBodyVersion
    ) internal override returns (address) {
        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            _localMessageTransmitter,
            _messageBodyVersion
        );
        return address(_tokenMessenger);
    }

    // Tests

    function testStorageSlots_hasAGapForDenylistableAdditions() public view {
        // Denylistable slots are arranged at slots 3-5
        // Sanity check this by reading from a Denylistable storage var
        // the denylister is stored at slot 3
        address _denylister = vm
            .load(address(localTokenMessenger), bytes32(uint256(3)))
            .toAddress();
        assertEq(_denylister, localTokenMessenger.denylister());

        // Check that the next storage vars, defined in BaseTokenMessenger, are gapped
        // by 20 slots
        // The localMinter is stored at slot 55
        address _localMinter = vm
            .load(address(localTokenMessenger), bytes32(uint256(25)))
            .toAddress();

        assertEq(_localMinter, address(localTokenMessenger.localMinter()));
    }

    function testInitialize_revertsIfOwnerIsZeroAddress() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );
        vm.expectRevert("Owner is the zero address");

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        TokenMessengerV2(address(_proxy)).initialize(
            address(0),
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfRescuerIsZeroAddress() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        vm.expectRevert("Rescuable: new rescuer is the zero address");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            address(0),
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfFeeRecipientIsZeroAddress() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        vm.expectRevert("Zero address not allowed");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            address(0),
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfDenylisterIsZeroAddress() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        vm.expectRevert("Denylistable: new denylister is the zero address");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            address(0),
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfTokenMinterIsZeroAddress() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        vm.expectRevert("Zero address not allowed");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(0),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfRemoteDomainsDoNotMatchRemoteMessengers()
        public
    {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        (uint32[] memory _remoteDomains, ) = _defaultRemoteTokenMessengers();

        // Add an extra remote token messenger
        bytes32[] memory _remoteTokenMessengers = new bytes32[](
            _remoteDomains.length + 1
        );
        for (uint256 i; i < _remoteTokenMessengers.length; i++) {
            _remoteTokenMessengers[i] = bytes32("test");
        }

        vm.expectRevert("Invalid remote domain configuration");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfRemoteTokenMessengerIsZeroAddress()
        public
    {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        bytes32[] memory _remoteTokenMessengers = new bytes32[](2);
        _remoteTokenMessengers[0] = bytes32("1");
        _remoteTokenMessengers[1] = bytes32(""); // empty

        uint32[] memory _remoteDomains = new uint32[](2);
        _remoteDomains[0] = 1;
        _remoteDomains[1] = 2;

        vm.expectRevert("bytes32(0) not allowed");
        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_succeedsIfRemoteDomainsIsEmpty() public {
        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        uint32[] memory _remoteDomains = new uint32[](0);
        bytes32[] memory _remoteTokenMessengers = new bytes32[](0);

        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_revertsIfCalledTwice() public {
        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        vm.expectRevert("Initializable: invalid initialization");
        localTokenMessenger.initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testInitialize_setsTheOwner() public view {
        assertEq(localTokenMessenger.owner(), owner);
    }

    function testInitialize_setsTheRescuer() public view {
        assertEq(localTokenMessenger.rescuer(), rescuer);
    }

    function testInitialize_setsTheFeeRecipient() public view {
        assertEq(localTokenMessenger.feeRecipient(), feeRecipient);
    }

    function testInitialize_setsTheDenylister() public view {
        assertEq(localTokenMessenger.denylister(), denylister);
    }

    function testInitialize_setsTheTokenMinter() public view {
        assertEq(
            address(localTokenMessenger.localMinter()),
            address(localTokenMinter)
        );
    }

    function testInitialize_setsSingleRemoteTokenMessenger() public view {
        assertEq(
            bytes32(localTokenMessenger.remoteTokenMessengers(remoteDomain)),
            remoteTokenMessengerAddr
        );
    }

    function testInitialize_setsMultipleRemoteTokenMessengers() public {
        bytes32[] memory _remoteTokenMessengers = new bytes32[](2);
        _remoteTokenMessengers[0] = bytes32("1");
        _remoteTokenMessengers[1] = bytes32("2");

        uint32[] memory _remoteDomains = new uint32[](2);
        _remoteDomains[0] = 1;
        _remoteDomains[1] = 2;

        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        TokenMessengerV2(address(_proxy)).initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
        assertEq(
            bytes32(TokenMessengerV2(address(_proxy)).remoteTokenMessengers(1)),
            bytes32("1")
        );
        assertEq(
            bytes32(TokenMessengerV2(address(_proxy)).remoteTokenMessengers(2)),
            bytes32("2")
        );
    }

    function testInitialize_setsTheInitializedVersion() public view {
        assertEq(uint256(localTokenMessenger.initializedVersion()), 1);
    }

    function testInitialize_canBeCalledAtomicallyByTheProxy() public {
        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            abi.encodeWithSelector(
                TokenMessengerV2.initialize.selector,
                owner,
                rescuer,
                feeRecipient,
                denylister,
                address(localTokenMinter),
                _remoteDomains,
                _remoteTokenMessengers
            )
        );
        assertEq(TokenMessengerV2(address(_proxy)).owner(), owner);
        assertEq(TokenMessengerV2(address(_proxy)).rescuer(), rescuer);
        assertEq(
            TokenMessengerV2(address(_proxy)).feeRecipient(),
            feeRecipient
        );
        assertEq(
            uint256(TokenMessengerV2(address(_proxy)).initializedVersion()),
            1
        );
        assertEq(TokenMessengerV2(address(_proxy)).denylister(), denylister);
        assertEq(
            address(TokenMessengerV2(address(_proxy)).localMinter()),
            address(localTokenMinter)
        );
        assertEq(
            TokenMessengerV2(address(_proxy)).remoteTokenMessengers(
                remoteDomain
            ),
            remoteTokenMessengerAddr
        );
    }

    function testInitialize_emitsEvents() public {
        (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        ) = _defaultRemoteTokenMessengers();

        AdminUpgradableProxy _proxy = new AdminUpgradableProxy(
            address(tokenMessengerImpl),
            proxyAdmin,
            bytes("")
        );

        TokenMessengerV2 _tokenMessenger = TokenMessengerV2(address(_proxy));

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), owner);

        vm.expectEmit(true, true, true, true);
        emit RescuerChanged(rescuer);

        vm.expectEmit(true, true, true, true);
        emit DenylisterChanged(address(0), denylister);

        vm.expectEmit(true, true, true, true);
        emit FeeRecipientSet(feeRecipient);

        vm.expectEmit(true, true, true, true);
        emit LocalMinterAdded(address(localTokenMinter));

        vm.expectEmit(true, true, true, true);
        emit RemoteTokenMessengerAdded(remoteDomain, remoteTokenMessengerAddr);

        _tokenMessenger.initialize(
            owner,
            rescuer,
            feeRecipient,
            denylister,
            address(localTokenMinter),
            _remoteDomains,
            _remoteTokenMessengers
        );
    }

    function testUpgrade_succeeds() public {
        AdminUpgradableProxy _proxy = AdminUpgradableProxy(
            payable(address(localTokenMessenger))
        );

        // Sanity check
        assertEq(_proxy.implementation(), address(tokenMessengerImpl));

        // Test that we can upgrade to a v3 TokenMessenger
        // Deploy v3 implementation
        MockTokenMessengerV3 _implV3 = new MockTokenMessengerV3(
            localMessageTransmitter,
            messageBodyVersion + 1
        );

        // Upgrade
        vm.prank(proxyAdmin);
        vm.expectEmit(true, true, true, true);
        emit Upgraded(address(_implV3));
        _proxy.upgradeTo(address(_implV3));

        // Sanity checks
        assertEq(_proxy.implementation(), address(_implV3));
        assertTrue(MockTokenMessengerV3(address(_proxy)).v3Function());
        // Check that the message body version is updated
        assertEq(
            uint256(localTokenMessenger.messageBodyVersion()),
            uint256(messageBodyVersion + 1)
        );
    }

    function testDepositForBurn_revertsIfMsgSenderIsOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 0);
        vm.assume(_messageSender != _txOriginator);

        // Add messageSender to deny list
        vm.prank(denylister);
        localTokenMessenger.denylist(_messageSender);
        assertTrue(localTokenMessenger.isDenylisted(_messageSender));
        assertFalse(localTokenMessenger.isDenylisted(_txOriginator));

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTxOriginatorIsOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 0);
        vm.assume(_messageSender != _txOriginator);

        // Add _txOriginator to deny list
        vm.prank(denylister);
        localTokenMessenger.denylist(_txOriginator);
        assertTrue(localTokenMessenger.isDenylisted(_txOriginator));
        assertFalse(localTokenMessenger.isDenylisted(_messageSender));

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfBothTxOriginatorAndMsgSenderAreOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_messageSender != _txOriginator);

        // Add both to deny list
        vm.startPrank(denylister);
        localTokenMessenger.denylist(_messageSender);
        localTokenMessenger.denylist(_txOriginator);
        assertTrue(localTokenMessenger.isDenylisted(_messageSender));
        assertTrue(localTokenMessenger.isDenylisted(_txOriginator));
        vm.stopPrank();

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTransferAmountIsZero(
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Amount must be nonzero");
        localTokenMessenger.depositForBurn(
            0, // amount
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfMintRecipientIsZero(
        uint256 _amount,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);

        vm.expectRevert("Mint recipient must be nonzero");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            bytes32(0), // mintRecipient
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfFeeEqualsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _amount, // maxFee
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfFeeExceedsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee > _amount);
        vm.assume(_mintRecipient != bytes32(0));

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurn(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfNoRemoteTokenMessengerExistsForDomain(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        vm.expectRevert("No TokenMessenger for domain");
        _tokenMessenger.depositForBurn(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfLocalMinterIsNotSet(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        _tokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            remoteTokenMessengerAddr
        );

        vm.expectRevert("Local minter is not set");
        _tokenMessenger.depositForBurn(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsOnFailedTokenTransfer(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        vm.mockCall(
            address(localToken),
            abi.encodeWithSelector(MockMintBurnToken.transferFrom.selector),
            abi.encode(false)
        );
        vm.expectRevert("Transfer operation failed");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTokenTransferReverts(
        address _caller,
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));

        // TransferFrom will revert, as localTokenMessenger has no allowance
        assertEq(
            localToken.allowance(_caller, address(localTokenMessenger)),
            0
        );

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_revertsIfTransferAmountExceedsMaxBurnAmountPerMessage(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);
        vm.assume(_caller != address(0));

        _setupDepositForBurn(_caller, _amount, _amount - 1);

        vm.prank(_caller);
        vm.expectRevert("Burn amount exceeds per tx limit");
        localTokenMessenger.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold
        );
    }

    function testDepositForBurn_succeeds(
        uint256 _amount,
        uint256 _burnLimit,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_amount < _burnLimit);
        vm.assume(_caller != address(0));

        uint256 _maxFee = _amount - 1;

        _setupDepositForBurn(_caller, _amount, _burnLimit);

        _depositForBurn(
            _caller,
            _mintRecipient,
            _destinationCaller,
            _amount,
            _maxFee,
            _minFinalityThreshold,
            msg.data[0:0]
        );
    }

    function testDepositForBurnWithHook_revertsIfMsgSenderIsOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 0);
        vm.assume(_messageSender != _txOriginator);

        // Add messageSender to deny list
        vm.prank(denylister);
        localTokenMessenger.denylist(_messageSender);
        assertTrue(localTokenMessenger.isDenylisted(_messageSender));
        assertFalse(localTokenMessenger.isDenylisted(_txOriginator));

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfTxOriginatorIsOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 0);
        vm.assume(_messageSender != _txOriginator);

        // Add txOriginator to deny list
        vm.prank(denylister);
        localTokenMessenger.denylist(_txOriginator);
        assertTrue(localTokenMessenger.isDenylisted(_txOriginator));
        assertFalse(localTokenMessenger.isDenylisted(_messageSender));

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfBothTxOriginatorAndMsgSenderAreOnDenylist(
        address _messageSender,
        address _txOriginator,
        uint256 _amount,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_messageSender != _txOriginator);

        // Add both to deny list
        vm.startPrank(denylister);
        localTokenMessenger.denylist(_messageSender);
        localTokenMessenger.denylist(_txOriginator);
        assertTrue(localTokenMessenger.isDenylisted(_messageSender));
        assertTrue(localTokenMessenger.isDenylisted(_txOriginator));
        vm.stopPrank();

        vm.prank(_messageSender, _txOriginator);
        vm.expectRevert("Denylistable: account is on denylist");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfHookIsEmpty(
        uint256 _amount,
        uint256 _maxFee,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);

        vm.expectRevert("Hook data is empty");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            bytes("")
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountIsZero(
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Amount must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            0, // amount
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            0,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfMintRecipientIsZero(
        uint256 _amount,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Mint recipient must be nonzero");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            bytes32(0), // mintRecipient
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeEqualsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _amount, // maxFee
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfFeeExceedsTransferAmount(
        uint256 _amount,
        address _burnToken,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee > _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.expectRevert("Max fee must be less than amount");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfNoRemoteTokenMessengerExistsForDomain(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        vm.expectRevert("No TokenMessenger for domain");
        _tokenMessenger.depositForBurnWithHook(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfLocalMinterIsNotSet(
        uint256 _amount,
        uint32 _remoteDomain,
        bytes32 _mintRecipient,
        address _burnToken,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        TokenMessengerV2 _tokenMessenger = new TokenMessengerV2(
            localMessageTransmitter,
            messageBodyVersion
        );

        _tokenMessenger.addRemoteTokenMessenger(
            _remoteDomain,
            remoteTokenMessengerAddr
        );

        vm.expectRevert("Local minter is not set");
        _tokenMessenger.depositForBurnWithHook(
            _amount,
            _remoteDomain,
            _mintRecipient,
            _burnToken,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsOnFailedTokenTransfer(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        vm.mockCall(
            address(localToken),
            abi.encodeWithSelector(MockMintBurnToken.transferFrom.selector),
            abi.encode(false)
        );
        vm.expectRevert("Transfer operation failed");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfTokenTransferReverts(
        address _caller,
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);

        // TransferFrom will revert, as localTokenMessenger has no allowance
        assertEq(
            localToken.allowance(_caller, address(localTokenMessenger)),
            0
        );

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_revertsIfTransferAmountExceedsMaxBurnAmountPerMessage(
        uint256 _amount,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_hookData.length > 0);
        vm.assume(_maxFee < _amount);
        vm.assume(_amount > 1);
        vm.assume(_caller != address(0));

        _setupDepositForBurn(_caller, _amount, _amount - 1);

        vm.prank(_caller);
        vm.expectRevert("Burn amount exceeds per tx limit");
        localTokenMessenger.depositForBurnWithHook(
            _amount,
            destinationDomain,
            _mintRecipient,
            address(localToken),
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testDepositForBurnWithHook_succeeds(
        uint256 _amount,
        uint256 _burnLimit,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData,
        address _caller
    ) public {
        vm.assume(_mintRecipient != bytes32(0));
        vm.assume(_amount > 1);
        vm.assume(_amount < _burnLimit);
        vm.assume(_hookData.length > 0);
        vm.assume(_caller != address(0));

        uint256 _maxFee = _amount - 1;

        _setupDepositForBurn(_caller, _amount, _burnLimit);

        _depositForBurn(
            _caller,
            _mintRecipient,
            _destinationCaller,
            _amount,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfCallerIsNotLocalMessageTransmitter(
        uint32 _remoteDomain,
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody,
        address _caller
    ) public {
        vm.assume(_caller != localMessageTransmitter);

        vm.expectRevert("Invalid message transmitter");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMessageSenderIsNotRemoteTokenMessengerForKnownDomain(
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_sender != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain, // known domain, but unknown remote token messenger addr
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMessageSenderIsKnownRemoteTokenMessengerForUnknownDomain(
        uint32 _remoteDomain,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            remoteTokenMessengerAddr, // known token messenger, but unknown domain
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsForUnknownRemoteTokenMessengersAndRemoteDomains(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessenger,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);
        vm.assume(_remoteTokenMessenger != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveFinalizedMessage(
            _remoteDomain,
            _remoteTokenMessenger,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsOnTooShortMessage(
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        // See: BurnMessageV2#HOOK_DATA_INDEX
        vm.assume(_messageBody.length < 228);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid burn message: too short");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsOnInvalidMessageBodyVersion(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_version != localTokenMessenger.messageBodyVersion());

        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid message body version");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfNonZeroExpirationBlockIsLessThanCurrentBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        uint32 _finalityThresholdExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_expirationBlock > 0);
        vm.assume(_expirationBlock < type(uint256).max - 1);
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Overwrite current block number to be greater than expirationBlock
        vm.roll(_expirationBlock + 1);
        assertTrue(vm.getBlockNumber() > _expirationBlock);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Message expired and must be re-signed");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfNonZeroExpirationBlockEqualsCurrentBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        uint32 _finalityThresholdExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_expirationBlock > 0);
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Overwrite current block number to equal expirationBlock
        vm.roll(_expirationBlock);
        assertEq(vm.getBlockNumber(), _expirationBlock);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Message expired and must be re-signed");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfFeeIsGreaterThanAmount(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);
        vm.assume(_feeExecuted > _amount);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee equals or exceeds amount");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfFeeEqualsAmount(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);
        vm.assume(_amount > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _amount, // feeExecuted == amount
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee equals or exceeds amount");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfFeeExecutedExceedsMaxFee(
        bytes32 _mintRecipient,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);
        vm.assume(_maxFee > 0);
        vm.assume(_feeExecuted > _maxFee);
        vm.assume(_feeExecuted < type(uint256).max - 1);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _feeExecuted + 1, // amount
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee exceeds max fee");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfNoLocalMinterIsSet(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        assertTrue(address(localTokenMessenger.localMinter()) != address(0));

        // Remove local minter
        vm.prank(owner);
        localTokenMessenger.removeLocalMinter();

        assertEq(address(localTokenMessenger.localMinter()), address(0));

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Local minter is not set");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMintRevertsWithZeroFees(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            0, // 0 fee executed, meaning that we'll use the regular mint() on TokenMinter
            0,
            _hookData
        );

        // Mock a failing call to TokenMinter mint() for amount
        bytes memory _call = abi.encodeWithSelector(
            TokenMinter.mint.selector,
            remoteDomain,
            remoteTokenAddr.toBytes32(),
            _mintRecipient.toAddress(),
            _amount
        );
        vm.mockCallRevert(
            address(localTokenMinter),
            _call,
            "Testing: mint() failed"
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Testing: mint() failed");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_revertsIfMintRevertsWithNonZeroFees(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted > 0);
        vm.assume(_feeExecuted < _amount);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted, // non-zero fee, meaning we'll try to mint() on TokenMinterV2, passing in multiple recipients
            0,
            _hookData
        );

        // Mock a failing call to TokenMinter mint() for amount, less fees
        bytes memory _call = abi.encodeWithSelector(
            TokenMinterV2.mint.selector,
            remoteDomain,
            remoteTokenAddr.toBytes32(),
            _mintRecipient.toAddress(),
            feeRecipient,
            _amount - _feeExecuted,
            _feeExecuted
        );
        vm.mockCallRevert(
            address(localTokenMinter),
            _call,
            "Testing: mint() failed"
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Testing: mint() failed");
        localTokenMessenger.handleReceiveFinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeedsForZeroExpirationBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted < _amount);
        vm.assume(_maxFee >= _feeExecuted);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0, // expiration
            _hookData
        );

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_FINALIZED,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeedsForNonZeroExpirationBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted < _amount);
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_FINALIZED,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeedsForZeroFee(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            0, // feeExecuted
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_FINALIZED,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeedsForNonZeroFee(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _expirationBlock,
        uint256 _feeExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_feeExecuted < _amount);
        vm.assume(_feeExecuted > 0);
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_FINALIZED,
            _messageBody
        );
    }

    function testHandleReceiveFinalizedMessage_succeeds(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _expirationBlock,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED);
        vm.assume(_maxFee < _amount);
        vm.assume(_expirationBlock > 0);

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        uint256 _feeExecuted = _maxFee;
        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfCallerIsNotLocalMessageTransmitter(
        uint32 _remoteDomain,
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody,
        address _caller
    ) public {
        vm.assume(_caller != localMessageTransmitter);

        vm.expectRevert("Invalid message transmitter");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            _remoteDomain,
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfMessageSenderIsNotRemoteTokenMessengerForKnownDomain(
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_sender != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain, // known domain, but unknown remote token messenger addr
            _sender,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfMessageSenderIsKnownRemoteTokenMessengerForUnknownDomain(
        uint32 _remoteDomain,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            _remoteDomain,
            remoteTokenMessengerAddr, // known token messenger, but unknown domain
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsForUnknownRemoteTokenMessengersAndRemoteDomains(
        uint32 _remoteDomain,
        bytes32 _remoteTokenMessenger,
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(_remoteDomain != remoteDomain);
        vm.assume(_remoteTokenMessenger != remoteTokenMessengerAddr);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Remote TokenMessenger unsupported");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            _remoteDomain,
            _remoteTokenMessenger,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsOnTooLowFinalityThreshold(
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        vm.assume(
            _finalityThresholdExecuted < TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Unsupported finality threshold");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsOnTooShortMessage(
        uint32 _finalityThresholdExecuted,
        bytes calldata _messageBody
    ) public {
        // See: BurnMessageV2#HOOK_DATA_INDEX
        vm.assume(_messageBody.length < 228);
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid burn message: too short");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsOnInvalidMessageBodyVersion(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(_version != localTokenMessenger.messageBodyVersion());
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );

        bytes memory _messageBody = BurnMessageV2._formatMessageForRelay(
            _version,
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Invalid message body version");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfNonZeroExpirationBlockIsLessThanCurrentBlock(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        vm.assume(_expirationBlock > 0);
        vm.assume(_expirationBlock < type(uint256).max - 1);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Overwrite current block number to be greater than expirationBlock
        vm.roll(_expirationBlock + 1);
        assertTrue(vm.getBlockNumber() > _expirationBlock);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Message expired and must be re-signed");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfNonZeroExpirationBlockEqualsCurrentBlock(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Overwrite current block number to equal expirationBlock
        vm.roll(_expirationBlock);
        assertEq(vm.getBlockNumber(), _expirationBlock);

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Message expired and must be re-signed");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfFeeIsGreaterThanAmount(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_feeExecuted > _amount);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee equals or exceeds amount");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfFeeEqualsAmount(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_amount > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _amount, // feeExecuted == amount
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee equals or exceeds amount");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfFeeExecutedExceedsMaxFee(
        bytes32 _mintRecipient,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_maxFee > 0);
        vm.assume(_feeExecuted > _maxFee);
        vm.assume(_feeExecuted < type(uint256).max - 1);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _feeExecuted + 1, // amount
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0,
            _hookData
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Fee exceeds max fee");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfNoLocalMinterIsSet(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_feeExecuted < _amount);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            0,
            _hookData
        );

        assertTrue(address(localTokenMessenger.localMinter()) != address(0));

        // Remove local minter
        vm.prank(owner);
        localTokenMessenger.removeLocalMinter();

        assertEq(address(localTokenMessenger.localMinter()), address(0));

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Local minter is not set");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfMintRevertsWithZeroFees(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            0, // 0 fee executed, meaning that we'll use the regular mint() on TokenMinter
            0,
            _hookData
        );

        // Mock a failing call to TokenMinter mint() for amount, less fees
        bytes memory _call = abi.encodeWithSelector(
            TokenMinter.mint.selector,
            remoteDomain,
            _burnToken,
            _mintRecipient.toAddress(),
            _amount
        );
        vm.mockCallRevert(
            address(localTokenMinter),
            _call,
            "Testing: mint() failed"
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Testing: mint() failed");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_revertsIfMintRevertsWithNonZeroFees(
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _feeExecuted,
        bytes calldata _hookData,
        uint32 _finalityThresholdExecuted
    ) public {
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted > 0);
        vm.assume(_feeExecuted < _amount);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            _burnToken,
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted, // non-zero fee, meaning we'll try to mint() on TokenMinterV2, passing in multiple recipients
            0,
            _hookData
        );

        // Mock a failing call to TokenMinter mint() for amount, less fees
        bytes memory _call = abi.encodeWithSelector(
            TokenMinterV2.mint.selector,
            remoteDomain,
            _burnToken,
            _mintRecipient.toAddress(),
            feeRecipient,
            _amount - _feeExecuted,
            _feeExecuted
        );
        vm.mockCallRevert(
            address(localTokenMinter),
            _call,
            "Testing: mint() failed"
        );

        vm.prank(localMessageTransmitter);
        vm.expectRevert("Testing: mint() failed");
        localTokenMessenger.handleReceiveUnfinalizedMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_succeedsForZeroExpirationBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted < _amount);
        vm.assume(_maxFee >= _feeExecuted);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            _feeExecuted,
            0, // expiration
            _hookData
        );

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_succeedsForNonZeroExpirationBlock(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        vm.assume(_amount > 0);
        vm.assume(_feeExecuted < _amount);
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_succeedsForZeroFee(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _maxFee,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) public {
        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _maxFee,
            0, // feeExecuted
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_succeedsForNonZeroFee(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _expirationBlock,
        uint256 _feeExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_feeExecuted < _amount);
        vm.assume(_feeExecuted > 0);
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    function testHandleReceiveUnfinalizedMessage_succeeds(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _expirationBlock,
        uint256 _feeExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_feeExecuted < _amount);
        vm.assume(_expirationBlock > 0);

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            FINALITY_THRESHOLD_CONFIRMED,
            _messageBody
        );
    }

    // Overall fuzz test for both finalized and unfinalized messages
    function testHandleReceivedMessage_succeeds(
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _burnMessageSender,
        uint256 _expirationBlock,
        uint256 _feeExecuted,
        uint32 _finalityThresholdExecuted,
        bytes calldata _hookData
    ) public {
        vm.assume(_feeExecuted < _amount);
        vm.assume(_expirationBlock > 0);
        vm.assume(
            _finalityThresholdExecuted >= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD
        );

        bytes memory _messageBody = _formatBurnMessageForReceive(
            localTokenMessenger.messageBodyVersion(),
            remoteTokenAddr.toBytes32(),
            _mintRecipient,
            _amount,
            _burnMessageSender,
            _feeExecuted, // maxFee
            _feeExecuted,
            _expirationBlock,
            _hookData
        );

        // Jump to a block height lower than the expiration block
        vm.roll(_expirationBlock - 1);

        _handleReceiveMessage(
            remoteDomain,
            remoteTokenMessengerAddr,
            _finalityThresholdExecuted,
            _messageBody
        );
    }

    // Test helpers

    function _defaultRemoteTokenMessengers()
        internal
        view
        returns (
            uint32[] memory _remoteDomains,
            bytes32[] memory _remoteTokenMessengers
        )
    {
        _remoteDomains = new uint32[](1);
        _remoteDomains[0] = remoteDomain;

        _remoteTokenMessengers = new bytes32[](1);
        _remoteTokenMessengers[0] = remoteTokenMessengerAddr;
    }

    function _formatBurnMessageForReceive(
        uint32 _version,
        bytes32 _burnToken,
        bytes32 _mintRecipient,
        uint256 _amount,
        bytes32 _messageSender,
        uint256 _maxFee,
        uint256 _feeExecuted,
        uint256 _expirationBlock,
        bytes calldata _hookData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _version,
                _burnToken,
                _mintRecipient,
                _amount,
                _messageSender,
                _maxFee,
                _feeExecuted,
                _expirationBlock,
                _hookData
            );
    }

    function _setupDepositForBurn(
        address _caller,
        uint256 _amount,
        uint256 _maxBurnAmount
    ) internal {
        localToken.mint(_caller, _amount);

        vm.prank(_caller);
        localToken.approve(address(localTokenMessenger), _amount);

        vm.prank(tokenController);
        localTokenMinter.setMaxBurnAmountPerMessage(
            address(localToken),
            _maxBurnAmount
        );
    }

    function _depositForBurn(
        address _caller,
        bytes32 _mintRecipient,
        bytes32 _destinationCaller,
        uint256 _amount,
        uint256 _maxFee,
        uint32 _minFinalityThreshold,
        bytes calldata _hookData
    ) internal {
        bytes memory _expectedBurnMessage = BurnMessageV2
            ._formatMessageForRelay(
                localTokenMessenger.messageBodyVersion(), // version
                address(localToken).toBytes32(), // burn token
                _mintRecipient, // mint recipient
                _amount, // amount
                _caller.toBytes32(), // sender
                _maxFee, // max fee
                _hookData
            );

        // expect burn() on localTokenMinter
        vm.expectCall(
            address(localTokenMinter),
            abi.encodeWithSelector(
                localTokenMinter.burn.selector,
                address(localToken),
                _amount
            )
        );

        // expect sendMessage() on localMessageTransmitter
        vm.expectCall(
            address(localMessageTransmitter),
            abi.encodeWithSelector(
                MessageTransmitterV2.sendMessage.selector,
                destinationDomain,
                remoteTokenMessengerAddr,
                _destinationCaller,
                _minFinalityThreshold,
                _expectedBurnMessage
            )
        );

        // Mock an empty response from messageTransmitter
        vm.mockCall(
            address(localMessageTransmitter),
            abi.encodeWithSelector(MessageTransmitterV2.sendMessage.selector),
            bytes("")
        );

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit DepositForBurn(
            address(localToken),
            _amount,
            _caller,
            _mintRecipient,
            destinationDomain,
            remoteTokenMessengerAddr,
            _destinationCaller,
            _maxFee,
            _minFinalityThreshold,
            _hookData
        );

        vm.prank(_caller);

        if (_hookData.length == 0) {
            localTokenMessenger.depositForBurn(
                _amount,
                destinationDomain,
                _mintRecipient,
                address(localToken),
                _destinationCaller,
                _maxFee,
                _minFinalityThreshold
            );
        } else {
            localTokenMessenger.depositForBurnWithHook(
                _amount,
                destinationDomain,
                _mintRecipient,
                address(localToken),
                _destinationCaller,
                _maxFee,
                _minFinalityThreshold,
                _hookData
            );
        }
    }

    function _handleReceiveMessage(
        uint32 _remoteDomain,
        bytes32 _sender,
        uint32 _finalityThresholdExecuted,
        bytes memory _messageBody
    ) internal {
        bytes29 _msg = _messageBody.ref(0);
        address _mintRecipient = _msg._getMintRecipient().toAddress();
        uint256 _amount = _msg._getAmount();
        uint256 _fee = _msg._getFeeExecuted();

        // Sanity checks to ensure this is being called with appropriate inputs
        assertEq(
            uint256(localTokenMessenger.messageBodyVersion()),
            uint256(_msg._getVersion())
        );
        assertEq(uint256(_remoteDomain), uint256(remoteDomain));
        assertEq(_sender, remoteTokenMessengerAddr);
        assertEq(_msg._getBurnToken().toAddress(), remoteTokenAddr);
        assertTrue(_fee == 0 || _amount > _fee);
        assertTrue(feeRecipient != address(0));
        vm.assume(_mintRecipient != feeRecipient);

        // Sanity check that the starting balances are 0
        assertEq(localToken.balanceOf(_mintRecipient), 0);
        assertEq(localToken.balanceOf(feeRecipient), 0);

        // Expect that TokenMinter be called 1x
        {
            bytes memory _encodedMinterCall;
            if (_fee == 0) {
                _encodedMinterCall = abi.encodeWithSelector(
                    TokenMinter.mint.selector,
                    _remoteDomain,
                    _msg._getBurnToken(),
                    _mintRecipient,
                    _amount
                );
            } else {
                _encodedMinterCall = abi.encodeWithSelector(
                    TokenMinterV2.mint.selector,
                    _remoteDomain,
                    _msg._getBurnToken(),
                    _mintRecipient,
                    feeRecipient,
                    _amount - _fee,
                    _fee
                );
            }
            vm.expectCall(address(localTokenMinter), _encodedMinterCall, 1);
        }

        vm.expectEmit(true, true, true, true); // Expect MintAndWithdraw to be emitted
        emit MintAndWithdraw(
            _mintRecipient,
            _amount - _fee,
            address(localToken),
            _fee
        );

        // Execute handleReceive()
        vm.prank(localMessageTransmitter);

        bool _result;
        if (_finalityThresholdExecuted >= FINALITY_THRESHOLD_FINALIZED) {
            _result = localTokenMessenger.handleReceiveFinalizedMessage(
                _remoteDomain,
                _sender,
                _finalityThresholdExecuted,
                _messageBody
            );
        } else {
            _result = localTokenMessenger.handleReceiveUnfinalizedMessage(
                _remoteDomain,
                _sender,
                _finalityThresholdExecuted,
                _messageBody
            );
        }

        assertTrue(_result);

        // Check balances after
        assertEq(
            _amount - _fee,
            localToken.balanceOf(_mintRecipient),
            "Mint recipient received incorrect amount"
        );
        assertEq(
            _fee,
            localToken.balanceOf(feeRecipient),
            "Fee recipient received incorrect amount"
        );
    }
}
