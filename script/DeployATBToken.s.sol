// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ATBToken.sol";

contract DeployATBToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Replace with the actual required token address on Linea
        address requiredTokenAddress = address(0x1789e0043623282D5DCc7F213d703C6D8BAfBB04);
        address initialOwner = vm.addr(deployerPrivateKey);

        new ATBToken(requiredTokenAddress, initialOwner);

        vm.stopBroadcast();
    }
}
