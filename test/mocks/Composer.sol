// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

/// @title ComposedReceiver
/// @dev A contract demonstrating the minimum ILayerZeroComposer interface necessary to receive composed messages via LayerZero.
contract ComposedReceiver is ILayerZeroComposer {
    /// @notice Stores the last received message.
    string public data = "Nothing received yet";

    /// @notice Store LayerZero addresses.
    address public immutable endpoint;
    address public immutable oApp;

    /// @notice Constructs the contract.
    /// @dev Initializes the contract.
    /// @param _endpoint LayerZero Endpoint address
    /// @param _oApp The address of the OApp that is sending the composed message.
    constructor(address _endpoint, address _oApp) {
        endpoint = _endpoint;
        oApp = _oApp;
    }

    /// @notice Handles incoming composed messages from LayerZero.
    /// @dev Decodes the message payload and updates the state.
    /// @param _oApp The address of the originating OApp.
    /// @param /*_guid*/ The globally unique identifier of the message.
    /// @param _message The encoded message content.
    function lzCompose(
        address _oApp,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address,
        bytes calldata
    ) external payable override {
        // Perform checks to make sure composed message comes from correct OApp.
        require(_oApp == oApp, "!oApp");
        require(msg.sender == endpoint, "!endpoint");

        // Decode the payload to get the message
        (string memory message, ) = abi.decode(_message, (string, address));
        data = message;
    }
}
