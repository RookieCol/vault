// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
interface IStrategy {
    function executeBuy(address token, uint256 amount) external payable returns (uint256);
    function executeSell(address token, uint256 amount) external payable returns (uint256);
}
