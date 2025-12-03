// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ABTDistributor.sol"; // Ensure the path is correct

contract SetCampaignConfig is Script {
    function run() external {
        // --- Configuration ---
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Read the distributor address from the environment variable
        address distributorAddress = vm.envAddress("DISTRIBUTOR_ADDRESS");
        
        address initialOwner = vm.addr(deployerPrivateKey);

        // Security Check: Ensure the address was successfully loaded
        require(distributorAddress != address(0), "DISTRIBUTOR_ADDRESS environment variable not set or invalid.");
        
        // --- Campaign Parameters (Input in WHOLE tokens) ---
        uint256 rewardAmountWhole = 1;   // 10 requiredToken per user
        uint256 dailyCapWhole = 1;     // Max 1000 requiredToken distributed daily globally
        bool isActive = true;

        // --- Start Transaction ---
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployed contract instance
        ABTDistributor abtDistributor = ABTDistributor(distributorAddress);
        
        console.log("Owner Address: %s", initialOwner);
        console.log("ABTDistributor Address: %s", address(abtDistributor));
        
        console.log("Setting Campaign Configuration...");
        console.log("Reward Amount (Whole): %s", rewardAmountWhole);
        console.log("Daily Cap (Whole): %s", dailyCapWhole);
        console.log("Is Active: %s", isActive);

        // Execute the external call
        // NOTE: This call must be made from the 'initialOwner' address defined in the contract constructor.
        abtDistributor.setCampaignConfig(
            isActive,
            rewardAmountWhole,
            dailyCapWhole
        );

        console.log("ABTDistributor: Campaign config set successfully.");

        vm.stopBroadcast();
        // --- Transaction Complete ---
    }
}