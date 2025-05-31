// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { MyOFT } from "../contracts/tokens/MyOFT.sol";

// Deploy on Sepolia (Source Chain)
contract DeploySepoliaOFT is Script {
    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
    address deployerAddr = vm.addr(deployerPrivateKey);

    // Sepolia LayerZero Endpoint
    address constant SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    uint32 constant SEPOLIA_EID = 40161;

    function setUp() public {}

    function run() public {
        console.log("=== Deploying Sepolia System ===");
        console.log("Deployer:", deployerAddr);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Stargate OFT on Sepolia
        MyOFT stargateOFT = new MyOFT("Stargate Token", "STG", SEPOLIA_ENDPOINT, deployerAddr);

        vm.stopBroadcast();

        console.log("\n=== SEPOLIA ADDRESSES ===");
        console.log("STARGATE_OFT=", address(stargateOFT));
    }
}
