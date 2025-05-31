// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IStrategy} from "../interfaces/IStrategy.sol";
import { IStargate } from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import { MessagingFee, SendParam, OFTReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Strategy is IStrategy {
    
    // Strategy state
    address public stargateRouter;
    address public owner;
    address public composer; // destination chain composer address
    uint32 public dstChainId; // destination chain ID
    
    event CrosschainBuyExecuted(address indexed token, uint256 amount);
    event CrosschainSellExecuted(address indexed token, uint256 amount);

    using SafeERC20 for IERC20;

    // ============ Constructor ============

    /**
     * @dev Constructor
     * @param _stargateRouter The address of the Stargate router
     * @param _owner The address of the vault
     */
    constructor(address _stargateRouter, address _owner) {
        owner = _owner;
        stargateRouter = _stargateRouter;
    }
    
    /**
     * @dev Execute crosschain buy using Stargate
     * @param token The token address to buy on the destination chain
     * @param amount The amount to buy
     */
    function executeBuy(address token, uint256 amount) external payable override returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");
        
        // Encode the buy instruction for the destination chain
        bytes memory composeMsg = abi.encode("",token, amount, msg.sender);
        
        // Call prepareTakeTaxi from the imported contract
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = 
            prepareTakeTaxiAndAMMSwap(
                stargateRouter,
                dstChainId,
                amount,
                composer,
                composeMsg
            );
        
        require(msg.value >= valueToSend, "Insufficient value for crosschain transfer");
        
        // Execute the crosschain transfer
        IStargate stargate = IStargate(stargateRouter);
        stargate.sendToken{value: valueToSend}(sendParam, messagingFee, msg.sender);
        
        emit CrosschainBuyExecuted(token, amount);
        
        return amount;
    }

    /**
     * @dev Execute crosschain sell using Stargate
     * @param token The token address to sell on the destination chain
     * @param amount The amount to sell
     */
    function executeSell(address token, uint256 amount) external payable override returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");
        
        // Encode the sell instruction for the destination chain
        bytes memory composeMsg = abi.encode("", token, amount, msg.sender);
        
        // Call prepareTakeTaxi from the imported contract
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = 
            prepareTakeTaxiAndAMMSwap(
                stargateRouter,
                dstChainId,
                amount,
                composer,
                composeMsg
            );
        
        require(msg.value >= valueToSend, "Insufficient value for crosschain transfer");
        
        // Execute the crosschain transfer
        IStargate stargate = IStargate(stargateRouter);
        stargate.sendToken{value: valueToSend}(sendParam, messagingFee, msg.sender);
        
        emit CrosschainSellExecuted(token, amount);
        
        return amount;
    }

    // ============ Configuration Functions ============
    
    /**
     * @dev Set the destination chain composer address
     * @param _composer The composer contract address on destination chain
     */
    function setComposer(address _composer) external  {
        composer = _composer;
    }
    
    /**
     * @dev Set the destination chain ID
     * @param _dstChainId The destination chain ID
     */
    function setDestinationChain(uint32 _dstChainId) external  {
        dstChainId = _dstChainId;
    }
    
    /**
     * @dev Update Stargate router address
     * @param _stargateRouter The new Stargate router address
     */
    function setStargateRouter(address _stargateRouter) external  {
        stargateRouter = _stargateRouter;
    }

    /**
     * @dev Quote the cost for crosschain transfer
     * @param token The token address
     * @param amount The amount
     * @param action The action ("BUY" or "SELL")
     */
    function quoteCrosschainTransfer(
        address token,
        uint256 amount,
        string memory action
    ) external view returns (uint256 valueToSend, MessagingFee memory messagingFee) {
        require(composer != address(0), "Composer not set");
        require(dstChainId != 0, "Destination chain not set");
        
        bytes memory composeMsg = abi.encode(action, token, amount, msg.sender);
        
        (valueToSend, , messagingFee) = prepareTakeTaxiAndAMMSwap(
            stargateRouter,
            dstChainId,
            amount,
            composer,
            composeMsg
        );
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}

    function prepareTakeTaxiAndAMMSwap(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg
    ) internal view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = _composeMsg.length > 0
            ? OptionsBuilder.addExecutorLzComposeOption(OptionsBuilder.newOptions(), 0, 2e5, 0)
            : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: bytes32(uint256(uint160(_composer))),
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
        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function withdrawERC20(address token, uint256 amount) external {
        require(msg.sender == owner, "Not authorized");
        IERC20(token).safeTransfer(owner, amount);
    }
}
