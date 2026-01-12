// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PublicChat} from "../src/Publicchat.sol";
import "forge-std/console.sol";

contract DeployPublicChat is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PublicChat publicChat = new PublicChat();
        console.log("Deployed PublicChat at:", address(publicChat));

        publicChat.renounceOwnership();

        vm.stopBroadcast();
    }
}
