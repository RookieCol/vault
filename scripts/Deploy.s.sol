// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { Strategy } from "../src/strategies/Strategy.sol";
import { Vault } from "../src/Vault.sol";
import { MyOFT } from "../src/tokens/MyOFT.sol";

// Deploy on Sepolia (Source Chain)
contract DeploySepoliaSystem is Script {
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
        console.log("Stargate OFT deployed at:", address(stargateOFT));

        // 2. Deploy Strategy contract
        Strategy strategy = new Strategy(address(stargateOFT));
        console.log("Strategy deployed at:", address(strategy));

        // 3. Deploy Vault
        Vault vault = new Vault(stargateOFT, "Stargate Vault", "SGV", address(strategy), deployerAddr);
        console.log("Vault deployed at:", address(vault));

        // 4. Mint tokens for testing
        stargateOFT.mint(address(vault), 1000000 * 1e18);
        stargateOFT.mint(deployerAddr, 100000 * 1e18);
        console.log("Minted tokens for testing");

        vm.stopBroadcast();

        console.log("\n=== SEPOLIA ADDRESSES ===");
        console.log("STARGATE_OFT=", address(stargateOFT));
        console.log("STRATEGY=", address(strategy));
        console.log("VAULT=", address(vault));
        console.log("Save these addresses for configuration!");
    }
}
