// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // ADD THIS IMPORT
import "./interfaces/IStrategy.sol";

contract Vault is ERC4626 {
    using SafeERC20 for IERC20; // ADD THIS LINE

    // Strategy contract
    IStrategy public strategy;

    // Access control - only this address can execute buy/sell
    address public allowedTrader;

    // FIXED: Add asset instance for easier access
    IERC20 private immutable _vaultAsset;

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
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _strategy,
        address _allowedTrader
    ) ERC20(_name, _symbol) ERC4626(_asset) {
        require(_strategy != address(0), "Strategy address cannot be zero");
        require(_allowedTrader != address(0), "Allowed trader address cannot be zero");

        strategy = IStrategy(_strategy);
        allowedTrader = _allowedTrader;
        _vaultAsset = _asset; // FIXED: Store asset reference

        emit StrategyUpdated(address(0), _strategy);
        emit AllowedTraderUpdated(address(0), _allowedTrader);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /// @dev Asset conversion to enforce 1:1 peg
    function _convertToShares(uint256 assets, Math.Rounding) internal pure override returns (uint256) {
        return assets;
    }

    function _convertToAssets(uint256 shares, Math.Rounding) internal pure override returns (uint256) {
        return shares;
    }

    function depositAssets(uint256 _assets) external {
        require(_assets > 0, "Deposit must be greater than zero");
        deposit(_assets, msg.sender);
    }

    /**
     * @dev Execute a buy operation through the strategy contract
     * @param _token The token address to buy
     * @param _amount The amount to buy
     * @return The result from the strategy execution
     */
    function buy(address _token, uint256 _amount) external payable onlyAllowedTrader returns (uint256) {
        require(_token != address(0), "Token address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");

        // FIXED: Use the asset instance correctly with proper method name
        // Option 1: Using the stored asset reference
        _vaultAsset.safeTransfer(address(strategy), _amount);

        // Option 2: Using the ERC4626 asset() function (alternative)
        // IERC20(asset()).safeTransfer(address(strategy), _amount);

        // Call the strategy's executeBuy function
        uint256 result = strategy.executeBuy{ value: msg.value }(_token, _amount);

        emit BuyExecuted(_token, _amount, result);

        return result;
    }

    /**
     * @dev Execute a sell operation through the strategy contract
     * @param _token The token address to sell
     * @param _amount The amount to sell
     * @return The result from the strategy execution
     */
    function sell(address _token, uint256 _amount) external payable onlyAllowedTrader returns (uint256) {
        require(_token != address(0), "Token address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");

        // Call the strategy's executeSell function
        uint256 result = strategy.executeSell{ value: msg.value }(_token, _amount);

        emit SellExecuted(_token, _amount, result);

        return result;
    }

    // ============ Admin Functions ============

    /**
     * @dev Update the allowed trader address (only current allowed trader can do this)
     * @param _newAllowedTrader The new allowed trader address
     */
    function updateAllowedTrader(address _newAllowedTrader) external onlyAllowedTrader {
        require(_newAllowedTrader != address(0), "New allowed trader address cannot be zero");

        address oldTrader = allowedTrader;
        allowedTrader = _newAllowedTrader;

        emit AllowedTraderUpdated(oldTrader, _newAllowedTrader);
    }

    /**
     * @dev Update the strategy contract (only allowed trader can do this)
     * @param _newStrategy The new strategy contract address
     */
    function updateStrategy(address _newStrategy) external onlyAllowedTrader {
        require(_newStrategy != address(0), "New strategy address cannot be zero");

        address oldStrategy = address(strategy);
        strategy = IStrategy(_newStrategy);

        emit StrategyUpdated(oldStrategy, _newStrategy);
    }

    /// @dev Withdraw function (burns shares and sends USDC)
    function withdrawAssets(uint256 _shares, address _receiver) external {
        require(_shares > 0, "Withdraw must be greater than zero");
        require(_receiver != address(0), "Invalid receiver");
        require(balanceOf(msg.sender) >= _shares, "Not enough shares");

        _burn(msg.sender, _shares);
        // FIXED: Use safeTransfer instead of transfer
        _vaultAsset.safeTransfer(_receiver, _shares);
    }

    // ============ View Functions ============

    /**
     * @dev Get the current strategy address
     */
    function getStrategy() external view returns (address) {
        return address(strategy);
    }

    /**
     * @dev Get the current allowed trader address
     */
    function getAllowedTrader() external view returns (address) {
        return allowedTrader;
    }

    /**
     * @dev Get the vault's underlying asset
     */
    function getAsset() external view returns (address) {
        return address(_vaultAsset);
    }

    // ============ Emergency Functions ============

    /**
     * @dev Emergency withdraw ETH (only allowed trader)
     */
    function emergencyWithdrawETH() external onlyAllowedTrader {
        payable(allowedTrader).transfer(address(this).balance);
    }

    /**
     * @dev Emergency withdraw any ERC20 token (only allowed trader)
     * @param _token The token address to withdraw
     * @param _amount The amount to withdraw
     */
    function emergencyWithdrawToken(address _token, uint256 _amount) external onlyAllowedTrader {
        require(_token != address(0), "Token address cannot be zero");
        // FIXED: Use safeTransfer
        IERC20(_token).safeTransfer(allowedTrader, _amount);
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
