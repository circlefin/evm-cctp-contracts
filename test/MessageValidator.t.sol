```solidity
// test/MessageValidator.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "ds-test/test.sol";
import "../contracts/MessageValidator.sol";

contract MessageValidatorTest is DSTest {
    function testInvalidChainId() public {
        MessageValidator validator = new MessageValidator();
        bool valid = validator.validateChainId(9999); // impossible chainId
        assertTrue(!valid, "Invalid chainId should return false");
    }
}
