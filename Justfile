set dotenv-load := true

default:
    just --list

setup:
    forge install
    cp .env.example .env

create-pool:
    forge script script/Create.s.sol:CreatePool --via-ir --rpc-url $SEPOLIA_RPC_URL --account w2 --sender 0x442d8202c886b10d7f13ed3f0f04f311a613b144 --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv

create-pool-v2:
    forge script script/CreateV2pool.s.sol:CreatePool --via-ir --rpc-url $SEPOLIA_RPC_URL --account w2 --sender 0x442d8202c886b10d7f13ed3f0f04f311a613b144 --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv

create-token:
    forge script scripts/deploy-s-oft.s.sol:DeploySepoliaOFT --rpc-url $SEPOLIA_RPC_URL --via-ir --account w2 --sender 0x442d8202c886b10d7f13ed3f0f04f311a613b144 --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv 

