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
import "../src/Message.sol";
import "../src/MessageTransmitter.sol";
import "./mocks/MockMintBurnToken.sol";
import "./mocks/MockRelayer.sol";

contract CircleBridgeTest is Test {
    CircleBridge circleBridge;
    MessageTransmitter srcMessageTransmitter;
    MockMintBurnToken mockMintBurnToken;
    address mockMintBurnTokenAddress;

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
     * @param destinationDomain destination domain
     * @param minter address of minter on destination domain as bytes32
     */
    event DepositForBurn(
        address depositor,
        address burnToken,
        uint256 amount,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 minter
    );

    /**
     * @notice Emitted when a supported burn token is added
     */
    event SupportedBurnTokenAdded(address burnToken);

    /**
     * @notice Emitted when a supported burn token is removed
     */
    event SupportedBurnTokenRemoved(address burnToken);

    uint32 sourceDomain = 0;
    uint32 version = 0;
    uint32 destinationDomain = 1;
    bytes32 minter = Message.addressToBytes32(vm.addr(1505));
    address owner = vm.addr(1506);
    uint32 maxMessageBodySize = 8 * 2**10;
    uint256 attesterPK = 1;
    address attester = vm.addr(attesterPK);

    function setUp() public {
        srcMessageTransmitter = new MessageTransmitter(
            sourceDomain,
            attester,
            maxMessageBodySize,
            version
        );

        circleBridge = new CircleBridge(address(srcMessageTransmitter));
        mockMintBurnToken = new MockMintBurnToken();
        mockMintBurnTokenAddress = address(mockMintBurnToken);

        circleBridge.addSupportedBurnToken(mockMintBurnTokenAddress);
    }

    function testDepositForBurnRevertsIfBurnTokenIsNotSupported() public {
        uint256 _amount = 1;

        // Fails because approve() was never called, allowance is 0.
        vm.expectRevert("Given burnToken is not supported");
        circleBridge.depositForBurn(
            _amount,
            destinationDomain,
            minter,
            vm.addr(1507)
        );
    }

    function testDepositForBurn_revertsIfTransferAmountIsZero() public {
        uint256 _amount = 0;

        // Fails because approve() was never called, allowance is 0.
        vm.expectRevert("MockMintBurnToken: burn amount not greater than 0");
        circleBridge.depositForBurn(
            _amount,
            destinationDomain,
            minter,
            mockMintBurnTokenAddress
        );
    }

    function testDepositForBurn_revertsIfTransferAmountExceedsAllowance()
        public
    {
        uint256 _amount = 1;

        // Fails because approve() was never called, allowance is 0.
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        circleBridge.depositForBurn(
            _amount,
            destinationDomain,
            minter,
            mockMintBurnTokenAddress
        );
    }

    function testDepositForBurn_revertsTransferringInsufficientFunds() public {
        uint256 _amount = 5;
        address _spender = address(circleBridge);

        mockMintBurnToken.mint(owner, 1);

        vm.prank(owner);
        mockMintBurnToken.approve(_spender, 10);

        vm.prank(owner);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        circleBridge.depositForBurn(
            _amount,
            destinationDomain,
            minter,
            mockMintBurnTokenAddress
        );
    }

    function testDepositForBurn_revertsIfRelayerReturnsFalse() public {
        uint256 _amount = 5;
        bytes32 _mintRecipient = Message.addressToBytes32(vm.addr(1505));

        MockRelayer _mockRelayer = new MockRelayer();
        address _mockRelayerAddress = address(_mockRelayer);
        CircleBridge _circleBridge = new CircleBridge(_mockRelayerAddress);

        _circleBridge.addSupportedBurnToken(mockMintBurnTokenAddress);

        mockMintBurnToken.mint(owner, 10);

        vm.prank(owner);
        mockMintBurnToken.approve(address(_circleBridge), 10);

        vm.prank(owner);
        vm.expectRevert("Relayer sendMessage() returned false");
        _circleBridge.depositForBurn(
            _amount,
            destinationDomain,
            _mintRecipient,
            mockMintBurnTokenAddress
        );
    }

    function testDepositForBurn_succeeds() public {
        uint256 _amount = 5;
        address _spender = address(circleBridge);
        bytes32 _mintRecipient = Message.addressToBytes32(vm.addr(1505));
        // TODO [BRAAV-11739]: use real minter in local mapping
        bytes32 _minter = bytes32("bar");

        mockMintBurnToken.mint(owner, 10);

        vm.prank(owner);
        mockMintBurnToken.approve(_spender, 10);

        // TODO [BRAAV-11739]: format message
        bytes memory _messageBody = bytes("foo");
        // assert that a MessageSent event was logged with expected message bytes
        uint64 _nonce = srcMessageTransmitter.availableNonces(
            destinationDomain
        );

        bytes memory _expectedMessage = Message.formatMessage(
            version,
            sourceDomain,
            destinationDomain,
            _nonce,
            Message.addressToBytes32(address(circleBridge)),
            _minter,
            _messageBody
        );

        vm.expectEmit(true, true, true, true);
        emit MessageSent(_expectedMessage);

        vm.expectEmit(true, true, true, true);
        emit DepositForBurn(
            owner,
            mockMintBurnTokenAddress,
            _amount,
            _mintRecipient,
            destinationDomain,
            _minter
        );

        vm.prank(owner);
        assertTrue(
            circleBridge.depositForBurn(
                _amount,
                destinationDomain,
                _mintRecipient,
                mockMintBurnTokenAddress
            )
        );
    }

    function testAddSupportedBurnToken(address _burnToken) public {
        // assert burnToken is not supported
        assertFalse(circleBridge.supportedBurnTokens(_burnToken));

        vm.expectEmit(true, true, true, true);
        emit SupportedBurnTokenAdded(_burnToken);

        // add burnToken as supported
        circleBridge.addSupportedBurnToken(_burnToken);

        // check that burnToken is now supported
        assertTrue(circleBridge.supportedBurnTokens(_burnToken));
    }

    function testAddSupportedBurnToken_failsIfAlreadySupported(
        address _burnToken
    ) public {
        // add burnToken as supported
        circleBridge.addSupportedBurnToken(_burnToken);

        // check that burnToken is now supported
        assertTrue(circleBridge.supportedBurnTokens(_burnToken));

        // try to add burnToken as supported again
        vm.expectRevert("burnToken already supported");
        circleBridge.addSupportedBurnToken(_burnToken);

        // check that burnToken is still supported
        assertTrue(circleBridge.supportedBurnTokens(_burnToken));
    }

    function testRemoveSupportedBurnToken(address _burnToken) public {
        // add burnToken as supported
        circleBridge.addSupportedBurnToken(_burnToken);

        // check that burnToken is now supported
        assertTrue(circleBridge.supportedBurnTokens(_burnToken));

        vm.expectEmit(true, true, true, true);
        emit SupportedBurnTokenRemoved(_burnToken);

        // remove supported burnToken
        circleBridge.removeSupportedBurnToken(_burnToken);

        // check that burnToken is now unsupported
        assertFalse(circleBridge.supportedBurnTokens(_burnToken));
    }

    function testRemoveSupportedBurnToken_failsIfNotAlreadyUnsupported(
        address _burnToken
    ) public {
        // check that burnToken is not supported
        assertFalse(circleBridge.supportedBurnTokens(_burnToken));

        // try to remove already unsupported burnToken
        vm.expectRevert("burnToken already unsupported");
        circleBridge.removeSupportedBurnToken(_burnToken);

        // check that burnToken is still unsupported
        assertFalse(circleBridge.supportedBurnTokens(_burnToken));
    }
}
