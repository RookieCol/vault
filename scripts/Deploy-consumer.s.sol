// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Receiver } from "../src/StargateComposer.sol";
import { MyOFT } from "../src/tokens/MyOFT.sol";

// Deploy on Optimism Sepolia (Destination Chain)
contract DeployOptimismSepoliaSystem is Script {
    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
    address deployerAddr = vm.addr(deployerPrivateKey);

    // Optimism Sepolia LayerZero Endpoint
    address constant OP_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    uint32 constant OP_SEPOLIA_EID = 40232;

    function setUp() public {}

    function run() public {
        console.log("=== Deploying Optimism Sepolia System ===");
        console.log("Deployer:", deployerAddr);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy destination Stargate OFT
        MyOFT destStargateOFT = new MyOFT("Stargate Token", "STG", OP_SEPOLIA_ENDPOINT, deployerAddr);
        console.log("Destination Stargate OFT deployed at:", address(destStargateOFT));

        // 2. Deploy StargateComposer
        StargateComposer stargateComposer = new StargateComposer();
        console.log("StargateComposer deployed at:", address(stargateComposer));

        // 3. Deploy ComposedReceiver
        ComposedReceiver composedReceiver = new ComposedReceiver(OP_SEPOLIA_ENDPOINT, address(destStargateOFT));
        console.log("ComposedReceiver deployed at:", address(composedReceiver));

        vm.stopBroadcast();

        console.log("\n=== OPTIMISM SEPOLIA ADDRESSES ===");
        console.log("DEST_STARGATE_OFT=", address(destStargateOFT));
        console.log("STARGATE_COMPOSER=", address(stargateComposer));
        console.log("COMPOSED_RECEIVER=", address(composedReceiver));
        console.log("Save these addresses for configuration!");
    }
}
