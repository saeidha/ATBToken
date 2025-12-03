// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
// Import the contracts from their respective paths (assuming src/ABTToken.sol and src/ABTDistributor.sol)
import "../src/ABTToken.sol";
import "../src/ABTDistributor.sol";

contract DeployABT is Script {
    function run() external {
        // --- Configuration ---
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Replace with the actual required token address (e.g., WETH or USDC on your target chain)
        address requiredTokenAddress = 0x1789e0043623282D5DCc7F213d703C6D8BAfBB04;
        address initialOwner = vm.addr(deployerPrivateKey);

        // --- Start Deployment ---
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deployer/Owner Address: %s", initialOwner);
        console.log("Required Token Address: %s", requiredTokenAddress);
        
        // 1. Deploy ABTToken
        ABTToken abtToken = new ABTToken(
            initialOwner // The owner is the deployer
        );
        console.log("ABTToken deployed to: %s", address(abtToken));

        // 2. Deploy ABTDistributor
        ABTDistributor abtDistributor = new ABTDistributor(
            address(abtToken),         // ABT Token Address
            requiredTokenAddress,      // Required Token Address
            initialOwner               // The owner is the deployer
        );
        console.log("ABTDistributor deployed to: %s", address(abtDistributor));

        // 3. Post-Deployment Setup: Authorize the Distributor
        // The ABTToken owner must set the distributor address
        abtToken.setDistributor(address(abtDistributor));
        console.log("ABTToken: Distributor set to ABTDistributor address.");
        
        vm.stopBroadcast();
        // --- Deployment Complete ---
    }
}