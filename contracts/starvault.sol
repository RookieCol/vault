// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStrategy.sol";

contract Vault is ERC4626 {
    using SafeERC20 for IERC20;

    // Strategy contract
    IStrategy public strategy;

    // Access control - only this address can execute buy/sell
    address public allowedTrader;

    // Events
    event BuyExecuted(address indexed token, uint256 amount, uint256 result);
    event SellExecuted(address indexed token, uint256 amount, uint256 result);
    event AllowedTraderUpdated(address indexed oldTrader, address indexed newTrader);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);

    modifier onlyAllowedTrader() {
        require(msg.sender == allowedTrader, "Only allowed trader can execute trades");
        _;
    }

    constructor(
        IERC20 _stargateToken, // The ONLY token this vault handles
        string memory _name,
        string memory _symbol,
        address _strategy,
        address _allowedTrader
    ) ERC20(_name, _symbol) ERC4626(_stargateToken) {
        require(_strategy != address(0), "Strategy address cannot be zero");
        require(_allowedTrader != address(0), "Allowed trader address cannot be zero");

        strategy = IStrategy(_strategy);
        allowedTrader = _allowedTrader;

        emit StrategyUpdated(address(0), _strategy);
        emit AllowedTraderUpdated(address(0), _allowedTrader);
    }

    function decimals() public view virtual override returns (uint8) {
        return IERC20Metadata(asset()).decimals(); // Use the Stargate token's decimals
    }

    /// @dev Asset conversion to enforce 1:1 peg
    function _convertToShares(uint256 assets, Math.Rounding) internal pure override returns (uint256) {
        return assets;
    }

    function _convertToAssets(uint256 shares, Math.Rounding) internal pure override returns (uint256) {
        return shares;
    }

    /**
     * @dev Deposit Stargate tokens into vault
     */
    function depositAssets(uint256 _assets) external {
        require(_assets > 0, "Deposit must be greater than zero");
        deposit(_assets, msg.sender);
    }

    /**
     * @dev Execute a buy operation through the strategy contract
     * Sends Stargate tokens to strategy for cross-chain transfer
     */
    function buy(address _token, uint256 _amount) external payable onlyAllowedTrader returns (uint256) {
        require(_token != address(0), "Token address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");

        // Send Stargate tokens to strategy for cross-chain transfer
        IERC20(asset()).safeTransfer(address(strategy), _amount);

        // Call the strategy's executeBuy function
        uint256 result = strategy.executeBuy{ value: msg.value }(_token, _amount);

        emit BuyExecuted(_token, _amount, result);
        return result;
    }

    /**
     * @dev Execute a sell operation through the strategy contract
     */
    function sell(address _token, uint256 _amount) external payable onlyAllowedTrader returns (uint256) {
        require(_token != address(0), "Token address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");

        // Send Stargate tokens to strategy for cross-chain transfer
        IERC20(asset()).safeTransfer(address(strategy), _amount);

        // Call the strategy's executeSell function
        uint256 result = strategy.executeSell{ value: msg.value }(_token, _amount);

        emit SellExecuted(_token, _amount, result);
        return result;
    }

    // ============ Admin Functions ============

    function updateAllowedTrader(address _newAllowedTrader) external onlyAllowedTrader {
        require(_newAllowedTrader != address(0), "New allowed trader address cannot be zero");

        address oldTrader = allowedTrader;
        allowedTrader = _newAllowedTrader;

        emit AllowedTraderUpdated(oldTrader, _newAllowedTrader);
    }

    function updateStrategy(address _newStrategy) external onlyAllowedTrader {
        require(_newStrategy != address(0), "New strategy address cannot be zero");

        address oldStrategy = address(strategy);
        strategy = IStrategy(_newStrategy);

        emit StrategyUpdated(oldStrategy, _newStrategy);
    }

    /// @dev Withdraw function (burns shares and sends Stargate tokens)
    function withdrawAssets(uint256 _shares, address _receiver) external {
        require(_shares > 0, "Withdraw must be greater than zero");
        require(_receiver != address(0), "Invalid receiver");
        require(balanceOf(msg.sender) >= _shares, "Not enough shares");

        _burn(msg.sender, _shares);
        IERC20(asset()).safeTransfer(_receiver, _shares);
    }

    // ============ View Functions ============

    function getStrategy() external view returns (address) {
        return address(strategy);
    }

    function getAllowedTrader() external view returns (address) {
        return allowedTrader;
    }

    function getStargateToken() external view returns (address) {
        return asset(); // The vault's underlying asset IS the Stargate token
    }

    // ============ Emergency Functions ============

    function emergencyWithdrawETH() external onlyAllowedTrader {
        payable(allowedTrader).transfer(address(this).balance);
    }

    function emergencyWithdrawToken(address _token, uint256 _amount) external onlyAllowedTrader {
        require(_token != address(0), "Token address cannot be zero");
        IERC20(_token).safeTransfer(allowedTrader, _amount);
    }

    receive() external payable {}
    fallback() external payable {}
}
