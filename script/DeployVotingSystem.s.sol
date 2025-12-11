// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ATBToken} from "../src/ATBToken.sol";
import {TokenVoting} from "../src/VotingSystem.sol";

contract DeployVotingSystem is Script {
    function run() public returns (TokenVoting) {
        vm.startBroadcast();

        // First, deploy a new ATBToken to get an address for the TokenVoting constructor.
        // In a real scenario, you would use an existing token address.
        ATBToken atbToken = new ATBToken(address(this), msg.sender);
        
        // Now deploy the TokenVoting with the new token's address.
        TokenVoting tokenVoting = new TokenVoting(address(atbToken));

        vm.stopBroadcast();
        return tokenVoting;
    }
}
