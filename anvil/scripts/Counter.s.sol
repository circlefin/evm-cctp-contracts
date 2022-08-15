pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../Counter.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new Counter(10);
        vm.stopBroadcast();
    }
}
