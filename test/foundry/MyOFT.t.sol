// pragma solidity ^0.8.20;

// // Mock imports
// import { OFTMock } from "../mocks/OFTMock.sol";
// import { ERC20Mock } from "../mocks/ERC20Mock.sol";
// import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

// // OApp imports
// import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
// import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// // OFT imports
// import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
// import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
// import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
// import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

// // OZ imports
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// import { ComposedReceiver } from "../mocks/Composer.sol";

// // Forge imports
// import "forge-std/console.sol";

// // DevTools imports
// import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// contract MyOFTTest is TestHelperOz5 {
//     using OptionsBuilder for bytes;

//     uint32 private aEid = 1;
//     uint32 private bEid = 2;

//     OFTMock private aOFT;
//     OFTMock private bOFT;

//     ComposedReceiver private consumer;

//     address private userA = makeAddr("userA");
//     address private userB = makeAddr("userB");
//     uint256 private initialBalance = 100 ether;

//     function setUp() public virtual override {
//         vm.deal(userA, 1000 ether);
//         vm.deal(userB, 1000 ether);

//         super.setUp();
//         setUpEndpoints(2, LibraryType.UltraLightNode);

//         aOFT = OFTMock(
//             _deployOApp(type(OFTMock).creationCode, abi.encode("aOFT", "aOFT", address(endpoints[aEid]), address(this)))
//         );

//         bOFT = OFTMock(
//             _deployOApp(type(OFTMock).creationCode, abi.encode("bOFT", "bOFT", address(endpoints[bEid]), address(this)))
//         );

//         consumer = new ComposedReceiver(endpoints[aEid], address(aOFT));

//         // config and wire the ofts
//         address[] memory ofts = new address[](2);
//         ofts[0] = address(aOFT);
//         ofts[1] = address(bOFT);
//         this.wireOApps(ofts);

//         // mint tokens
//         aOFT.mint(userA, initialBalance);
//         bOFT.mint(userB, initialBalance);
//     }

//     function test_constructor() public {
//         assertEq(aOFT.owner(), address(this));
//         assertEq(bOFT.owner(), address(this));

//         assertEq(aOFT.balanceOf(userA), initialBalance);
//         assertEq(bOFT.balanceOf(userB), initialBalance);

//         assertEq(aOFT.token(), address(aOFT));
//         assertEq(bOFT.token(), address(bOFT));
//     }

//     function test_send_oft() public {
//         uint256 tokensToSend = 1 ether;
//         bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
//         SendParam memory sendParam = SendParam(
//             bEid,
//             addressToBytes32(userB),
//             tokensToSend,
//             tokensToSend,
//             options,
//             "",
//             ""
//         );
//         MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

//         assertEq(aOFT.balanceOf(userA), initialBalance);
//         assertEq(bOFT.balanceOf(userB), initialBalance);

//         vm.prank(userA);
//         aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
//         verifyPackets(bEid, addressToBytes32(address(bOFT)));

//         assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
//         assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend);
//     }

//     function test_send_oft_compose_msg() public {
//         uint256 tokensToSend = 1 ether;

//         OFTComposerMock composer = new OFTComposerMock();

//         bytes memory options = OptionsBuilder
//             .newOptions()
//             .addExecutorLzReceiveOption(200000, 0)
//             .addExecutorLzComposeOption(0, 500000, 0);
//         bytes memory composeMsg = hex"1234";
//         SendParam memory sendParam = SendParam(
//             bEid,
//             addressToBytes32(address(composer)),
//             tokensToSend,
//             tokensToSend,
//             options,
//             composeMsg,
//             ""
//         );
//         MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

//         assertEq(aOFT.balanceOf(userA), initialBalance);
//         assertEq(bOFT.balanceOf(address(composer)), 0);

//         vm.prank(userA);
//         (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = aOFT.send{ value: fee.nativeFee }(
//             sendParam,
//             fee,
//             payable(address(this))
//         );
//         verifyPackets(bEid, addressToBytes32(address(bOFT)));

//         // lzCompose params
//         uint32 dstEid_ = bEid;
//         address from_ = address(bOFT);
//         bytes memory options_ = options;
//         bytes32 guid_ = msgReceipt.guid;
//         address to_ = address(composer);
//         bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
//             msgReceipt.nonce,
//             aEid,
//             oftReceipt.amountReceivedLD,
//             abi.encodePacked(addressToBytes32(userA), composeMsg)
//         );
//         this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

//         assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
//         assertEq(bOFT.balanceOf(address(composer)), tokensToSend);

//         assertEq(composer.from(), from_);
//         assertEq(composer.guid(), guid_);
//         assertEq(composer.message(), composerMsg_);
//         assertEq(composer.executor(), address(this));
//         assertEq(composer.extraData(), composerMsg_); // default to setting the extraData to the message as well to test
//     }

//     // TODO import the rest of oft tests?
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Test framework imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// Mock imports for OFT
import { OFTMock } from "../mocks/OFTMock.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

// LayerZero imports
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
//
import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

// Your actual contracts
import { Vault } from "../mocks/Vault.sol";
import { Strategy } from "../mocks/Strategy.sol"; // Your actual strategy
import { ComposedReceiver } from "../mocks/Composer.sol"; // Your actual composer

// OpenZeppelin imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ActualVaultStrategyTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    // Chain IDs
    uint32 private sourceEid = 1; // Source chain (where vault/strategy are)
    uint32 private destEid = 2; // Destination chain (where composer is)

    // OFT tokens on each chain (acting as Stargate for testing)
    OFTMock private sourceOFT;
    OFTMock private destOFT;

    // Mock USDC token for vault
    ERC20Mock private usdc;

    // Your actual contracts
    Vault private vault;
    Strategy private strategy;
    ComposedReceiver private composer;

    // Test users
    address private vaultOwner = makeAddr("vaultOwner");
    address private trader = makeAddr("trader");
    address private user = makeAddr("user");

    // Test amounts
    uint256 private initialBalance = 1000 ether;
    uint256 private userUSDCBalance = 10000 * 1e18; // 10k USDC (6 decimals)

    function setUp() public virtual override {
        // Setup users with ETH for gas
        vm.deal(vaultOwner, 1000 ether);
        vm.deal(trader, 1000 ether);
        vm.deal(user, 1000 ether);

        // Setup LayerZero endpoints
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy OFT tokens on both chains (these will act as Stargate for testing)
        sourceOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("SourceOFT", "SOFT", address(endpoints[sourceEid]), address(this))
            )
        );

        destOFT = OFTMock(
            _deployOApp(
                type(OFTMock).creationCode,
                abi.encode("DestOFT", "DOFT", address(endpoints[destEid]), address(this))
            )
        );

        // Wire the OFTs together for cross-chain communication
        address[] memory ofts = new address[](2);
        ofts[0] = address(sourceOFT);
        ofts[1] = address(destOFT);
        this.wireOApps(ofts);

        // Deploy mock USDC token
        usdc = new ERC20Mock("USD Coin", "USDC"); // 6 decimals like real USDC

        // Deploy your actual strategy contract (using sourceOFT as "stargate router" for testing)
        strategy = new Strategy(address(sourceOFT), vaultOwner);

        // Deploy your actual vault contract
        vm.prank(vaultOwner);
        vault = new Vault(IERC20(address(usdc)), "Test Vault", "TV", address(strategy), trader);

        // Deploy your actual composer on destination chain
        composer = new ComposedReceiver(address(endpoints[destEid]), address(destOFT));

        // Configure strategy
        strategy.setComposer(address(composer));
        strategy.setDestinationChain(destEid);

        // Setup initial balances
        sourceOFT.mint(address(strategy), initialBalance);
        sourceOFT.mint(address(this), initialBalance); // For manual testing
        destOFT.mint(address(composer), 0);
        sourceOFT.mint(user, initialBalance);
        usdc.mint(user, userUSDCBalance);

        // User approves vault to spend USDC
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_setup_verification() public {
        // Test basic setup
        assertEq(vault.getAllowedTrader(), trader);
        assertEq(vault.getStrategy(), address(strategy));
        assertEq(strategy.composer(), address(composer));
        assertEq(strategy.dstChainId(), destEid);
        assertEq(usdc.balanceOf(user), userUSDCBalance);
        assertEq(composer.data(), "Nothing received yet");
    }

    function test_vault_deposit() public {
        uint256 depositAmount = 1000 * 1e18; // 1000 USDC

        // User deposits USDC into vault
        vm.prank(user);
        vault.depositAssets(depositAmount);

        // Check vault balance
        assertEq(vault.balanceOf(user), depositAmount);
        assertEq(usdc.balanceOf(address(vault)), depositAmount);
    }

    function test_strategy_quote() public {
        uint256 amount = 100 * 1e18;

        // Test quote function
        (uint256 valueNeeded, MessagingFee memory fee) = strategy.quoteCrosschainTransfer(
            address(sourceOFT),
            amount,
            "BUY"
        );

        console.log("Quote - Value needed:", valueNeeded);
        console.log("Quote - Native fee:", fee.nativeFee);

        assertGt(valueNeeded, 0, "Should need some value for cross-chain");
        assertGt(fee.nativeFee, 0, "Should have native fee");
    }

    function test_compose_basic() public {
        // Test composer directly (skipping LayerZero complexity for now)
        bytes memory testMsg = abi.encode("BASIC_TEST", user);

        // Direct composer test
        vm.prank(address(endpoints[destEid]));
        composer.lzCompose(address(destOFT), bytes32(uint256(1234)), testMsg, address(this), "");

        assertEq(composer.data(), "BASIC_TEST");
    }

    function test_composer_direct_fixed() public {
        string memory message = "DIRECT_TEST";
        uint256 amount = 1 ether;

        // OPTION 1: Use OFTComposerMock with raw bytes (this should work)
        OFTComposerMock composer1 = new OFTComposerMock();
        bytes memory composeMsg = hex"1231";

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 300000, 0);

        SendParam memory sendParam = SendParam(
            destEid,
            addressToBytes32(address(composer1)),
            amount,
            amount,
            options,
            composeMsg,
            ""
        );

        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        vm.prank(user);
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = sourceOFT.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );

        verifyPackets(destEid, addressToBytes32(address(destOFT)));

        // Correct: user is the sender since we used vm.prank(user)
        bytes memory composerMsg = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            sourceEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(user), composeMsg)
        );

        this.lzCompose(destEid, address(destOFT), options, msgReceipt.guid, address(composer1), composerMsg);

        // Verify OFTComposerMock received the message
        assertEq(composer1.from(), address(destOFT));
        assertEq(composer1.guid(), msgReceipt.guid);
    }
    function test_vault_strategy_full_flow() public {
        uint256 depositAmount = 1000 * 1e18; // 1000 USDC
        uint256 buyAmount = 10 * 1e18; // 10 tokens to buy cross-chain

        // Step 1: User deposits USDC into vault
        vm.prank(user);
        vault.depositAssets(depositAmount);
        assertEq(vault.balanceOf(user), depositAmount);

        // Step 2: Get quote for cross-chain buy operation
        (uint256 valueNeeded, MessagingFee memory fee) = strategy.quoteCrosschainTransfer(
            address(sourceOFT),
            buyAmount,
            "BUY"
        );

        console.log("Cross-chain buy fee needed:", valueNeeded);

        // Step 3: Setup composer to receive the cross-chain action
        OFTComposerMock destinationComposer = new OFTComposerMock();

        // Update strategy to point to our test composer
        strategy.setComposer(address(destinationComposer));

        // Step 4: Fund strategy with tokens for the cross-chain transfer
        sourceOFT.mint(address(strategy), buyAmount);

        // Step 5: Trader executes buy on vault, which should trigger strategy
        vm.deal(trader, valueNeeded + 1 ether); // Give trader enough ETH for cross-chain fees

        vm.prank(trader);
        uint256 result = vault.buy{ value: valueNeeded }(address(sourceOFT), buyAmount);

        // Verify vault buy was successful
        assertEq(result, buyAmount);

        // Step 6: Verify cross-chain message was sent (check balances)
        // The strategy should have sent tokens cross-chain
        assertEq(sourceOFT.balanceOf(address(strategy)), initialBalance); // Strategy used its own tokens

        // Step 8: Verify the composer received the cross-chain call
        // The composer should have received tokens and the compose message
        // assertTrue(destOFT.balanceOf(address(destinationComposer)) > 0, "Composer should have received tokens");
        // assertEq(destinationComposer.from(), address(destOFT), "Compose message should be from destOFT");
    }
    function test_vault_strategy_with_your_composer() public {
        uint256 depositAmount = 100 ether; // 1000 USDC
        uint256 buyAmount = 5 ether; // 5 tokens

        // Step 1: User deposits
        vm.prank(user);
        vault.depositAssets(depositAmount);

        // Step 5: Trader executes buy on vault, which should trigger strategy

        // Step 2: Modify strategy to send proper message format for your ComposedReceiver
        // We need to create a custom strategy call that sends the right message format

        // Get quote for the operation
        (uint256 valueNeeded, ) = strategy.quoteCrosschainTransfer(address(sourceOFT), buyAmount, "BUY");

        vm.deal(trader, valueNeeded + 1 ether); // Give trader enough ETH for cross-chain fees

        vm.prank(trader);
        uint256 result = vault.buy{ value: valueNeeded }(address(sourceOFT), buyAmount);

        // Verify vault buy was successful
        assertEq(result, buyAmount);

        // assertEq(vault.balanceOf(user), depositAmount - buyAmount, "Vault should have reduced user balance"); //to fix
        // assertEq(usdc.balanceOf(address(vault)), depositAmount - buyAmount, "Vault should hold reduced USDC");

        // Step 3: Setup for manual cross-chain call with proper message format
        // string memory message = "VAULT_BUY_EXECUTED";
        // bytes memory composeMsg = hex"1212"; // Format your composer expects

        // bytes memory options = OptionsBuilder
        //     .newOptions()
        //     .addExecutorLzReceiveOption(200000, 0)
        //     .addExecutorLzComposeOption(0, 300000, 0);

        // SendParam memory sendParam = SendParam(
        //     destEid,
        //     addressToBytes32(address(composer)),
        //     buyAmount,
        //     buyAmount,
        //     options,
        //     composeMsg,
        //     ""
        // );

        // // Step 4: Execute the manual cross-chain call (simulating what strategy should do)
        // MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // vm.prank(trader);
        // (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = sourceOFT.send{ value: fee.nativeFee }(
        //     sendParam,
        //     fee,
        //     payable(address(this))
        // );

        // Step 5: Process the cross-chain message
        verifyPackets(destEid, addressToBytes32(address(destOFT)));

        bytes memory composerMsg = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            sourceEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(trader), composeMsg)
        );

        this.lzCompose(destEid, address(destOFT), options, msgReceipt.guid, address(composer), composerMsg);

        // Step 6: Verify your composer processed the vault buy
        assertEq(composer.data(), message);
        assertEq(destOFT.balanceOf(address(composer)), buyAmount);

        console.log("Vault buy successfully triggered cross-chain compose!");
    }
}
