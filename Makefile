#!/bin/bash

include .env

t:
  forge script DeploySepoliaOFT --chain $(SEPOLIA_CHAIN) --rpc-url $(SEPOLIA_RPC_URL) -vvvv -- --decode-internal

et:
  forge script TransferEth --chain $(SEPOLIA_CHAIN) --rpc-url $(SEPOLIA_RPC_URL) --broadcast -vvvv 

dc:
  forge script DeployComposer --chain $(OPT_CHAIN) --rpc-url $(OPT_RPC_URL) -vvvv -- --decode-internal

edc:
  forge script DeployComposer --chain $(OPT_CHAIN) --rpc-url $(OPT_RPC_URL)  --etherscan-api-key $(OPT_ETHERSCAN_API_KEY) --verifier $(VERIFIER) --verify --broadcast -vvvv 

dr:
  forge script DeployReceiver --chain $(SEPOLIA_CHAIN) --rpc-url $(SEPOLIA_RPC_URL) -vvvv -- --decode-internal

edr:
  forge script DeployReceiver --chain $(SEPOLIA_CHAIN) --rpc-url $(SEPOLIA_RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier $(VERIFIER) --verify --broadcast -vvvv