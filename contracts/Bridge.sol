```solidity
function send(address token, uint256 amount) external {
    require(allowedSenders[msg.sender], "Sender not allowed");
    // existing logic
    // …
}
