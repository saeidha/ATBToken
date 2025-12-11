// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenVoting} from "../src/VotingSystem.sol";

contract DeployVotingSystem is Script {
    function run() public returns (TokenVoting) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Use the provided requiredTokenAddress
        address requiredTokenAddress = 0x1789e0043623282D5DCc7F213d703C6D8BAfBB04;
        
        // Deploy the TokenVoting with the specified token address.
        TokenVoting tokenVoting = new TokenVoting(requiredTokenAddress);

        vm.stopBroadcast();
        return tokenVoting;
    }
}
