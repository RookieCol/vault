// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IStrategy } from "../interfaces/IStrategy.sol";
import { IStargate } from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import { MessagingFee, SendParam, OFTReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract Strategy is IStrategy {
    using OptionsBuilder for bytes;

    address public stargateRouter;
    address public composer; // destination chain composer address
    uint32 public dstChainId; // destination chain ID

    event CrosschainBuyExecuted(address indexed token, uint256 amount);
    event CrosschainSellExecuted(address indexed token, uint256 amount);

    constructor(address _stargateRouter) {
        stargateRouter = _stargateRouter;
    }

    /**
     * @dev Execute crosschain buy using Stargate
     * Vault sends Stargate tokens to this contract, then we send them cross-chain
     */
    function executeBuy(address token, uint256 amount) external payable override returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");

        // Create compose message for destination chain
        bytes memory composeMsg = abi.encode("BUY", token, amount, msg.sender);

        // Prepare the cross-chain transfer
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = prepare(
            stargateRouter,
            dstChainId,
            amount,
            composer,
            composeMsg,
            200_000 // compose function gas limit
        );

        require(msg.value >= valueToSend, "Insufficient value for crosschain transfer");

        // Execute the crosschain transfer using Stargate
        IStargate(stargateRouter).sendToken{ value: valueToSend }(sendParam, messagingFee, msg.sender);

        emit CrosschainBuyExecuted(token, amount);
        return amount;
    }

    /**
     * @dev Execute crosschain sell using Stargate
     */
    function executeSell(address token, uint256 amount) external payable override returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");

        // Create compose message for destination chain
        bytes memory composeMsg = abi.encode("SELL", token, amount, msg.sender);

        // Prepare the cross-chain transfer
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = prepare(
            stargateRouter,
            dstChainId,
            amount,
            composer,
            composeMsg,
            200_000 // compose function gas limit
        );

        require(msg.value >= valueToSend, "Insufficient value for crosschain transfer");

        // Execute the crosschain transfer using Stargate
        IStargate(stargateRouter).sendToken{ value: valueToSend }(sendParam, messagingFee, msg.sender);

        emit CrosschainSellExecuted(token, amount);
        return amount;
    }

    /**
     * @dev Prepare cross-chain transfer parameters (inspired by StargateComposer)
     */
    function prepare(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg,
        uint256 _composeFunctionGasLimit
    ) public view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = _composeMsg.length > 0
            ? OptionsBuilder
                .newOptions()
                .addExecutorLzComposeOption(
                    0, // compose call function index
                    uint128(_composeFunctionGasLimit), // compose function gas limit
                    0 // compose function msg value
                )
                .addExecutorLzReceiveOption(200000, 0)
            : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_composer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });

        IStargate stargate = IStargate(_stargate);
        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;
        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        // If sending native token (ETH), add amount to value
        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    /**
     * @dev Quote the cost for crosschain transfer
     */
    function quoteCrosschainTransfer(
        address token,
        uint256 amount,
        string memory action
    ) external view returns (uint256 valueToSend, MessagingFee memory messagingFee) {
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");

        bytes memory composeMsg = abi.encode(action, token, amount, msg.sender);
        (valueToSend, , messagingFee) = prepare(stargateRouter, dstChainId, amount, composer, composeMsg, 200_000);
    }

    // ============ Configuration Functions ============

    function setComposer(address _composer) external {
        composer = _composer;
    }

    function setDestinationChain(uint32 _dstChainId) external {
        dstChainId = _dstChainId;
    }

    function setStargateRouter(address _stargateRouter) external {
        stargateRouter = _stargateRouter;
    }

    // ============ Helper Functions ============

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    receive() external payable {}
    fallback() external payable {}
}
