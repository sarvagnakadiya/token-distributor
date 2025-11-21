 // // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.30;

// import {Test, console} from "forge-std/Test.sol";
// import {TokenDistributor, IERC20} from "../src/TokenDistributor.sol";

// /**
//  * @title MockERC20
//  * @notice Simple ERC20 implementation for testing
//  */
// contract MockERC20 is IERC20 {
//     string public name = "Mock Token";
//     string public symbol = "MOCK";
//     uint8 public decimals = 18;
//     uint256 public totalSupply;

//     mapping(address => uint256) private _balances;
//     mapping(address => mapping(address => uint256)) private _allowances;

//     constructor(uint256 _initialSupply) {
//         _balances[msg.sender] = _initialSupply;
//         totalSupply = _initialSupply;
//     }

//     function balanceOf(address account) external view returns (uint256) {
//         return _balances[account];
//     }

//     function transfer(address to, uint256 amount) external returns (bool) {
//         _balances[msg.sender] -= amount;
//         _balances[to] += amount;
//         return true;
//     }

//     function allowance(
//         address owner,
//         address spender
//     ) external view returns (uint256) {
//         return _allowances[owner][spender];
//     }

//     function approve(address spender, uint256 amount) external returns (bool) {
//         _allowances[msg.sender][spender] = amount;
//         return true;
//     }

//     function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) external returns (bool) {
//         require(
//             _allowances[from][msg.sender] >= amount,
//             "Insufficient allowance"
//         );
//         require(_balances[from] >= amount, "Insufficient balance");

//         _allowances[from][msg.sender] -= amount;
//         _balances[from] -= amount;
//         _balances[to] += amount;
//         return true;
//     }
// }

// /**
//  * @title TokenDistributorTest
//  * @notice Comprehensive test suite for TokenDistributor contract
//  */
// contract TokenDistributorTest is Test {
//     TokenDistributor public distributor;
//     MockERC20 public token;

//     address public distributorAddress;
//     address[] public recipients;

//     uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens
//     uint256 constant RECIPIENTS_COUNT = 1000;

//     uint256 mainnetFork;

//     function setUp() public {
//         mainnetFork = vm.createFork(vm.envString("FORK_URL"));
//         vm.selectFork(mainnetFork);
//         // Deploy contracts
//         distributor = new TokenDistributor();
//         token = new MockERC20(INITIAL_SUPPLY);

//         // Setup distributor address
//         distributorAddress = address(0x1234);

//         // Transfer tokens to distributor address
//         bool success = token.transfer(distributorAddress, INITIAL_SUPPLY / 2);
//         require(success, "Transfer failed");

//         // Clear and generate 1000 recipient addresses
//         delete recipients;
//         for (uint256 i = 0; i < RECIPIENTS_COUNT; i++) {
//             // casting to 'uint160' is safe because [explain why]
//             // forge-lint: disable-next-line(unsafe-typecast)
//             recipients.push(address(uint160(i + 1)));
//         }

//         console.log("Setup complete:");
//         console.log("- TokenDistributor deployed at:", address(distributor));
//         console.log("- MockERC20 deployed at:", address(token));
//         console.log("- Recipients generated:", recipients.length);
//         console.log(
//             "- Distributor balance:",
//             token.balanceOf(distributorAddress)
//         );
//     }

//     /**
//      * @notice Test distributing to 1000 addresses in a SINGLE transaction
//      * @dev This simulates the exact use case: 1000 addresses, single call, no batching
//      */
//     function test_SingleTransaction1000Addresses() public {
//         uint256 amountEach = 1_000 * 10 ** 18; // 1000 tokens each
//         uint256 totalAmount = amountEach * RECIPIENTS_COUNT; // 1 million tokens total

//         console.log("SINGLE TRANSACTION - 1000 ADDRESSES TEST");

//         // Approve tokens from distributor address
//         vm.prank(distributorAddress);
//         token.approve(address(distributor), totalAmount);

//         // Check initial balances
//         uint256 initialBalance = token.balanceOf(distributorAddress);
//         console.log("\n=== BEFORE DISTRIBUTION ===");
//         console.log("Recipients count       :", RECIPIENTS_COUNT);
//         console.log(
//             "Distributor balance    :",
//             initialBalance / 10 ** 18,
//             "tokens"
//         );
//         console.log(
//             "Total to distribute    :",
//             totalAmount / 10 ** 18,
//             "tokens"
//         );
//         console.log(
//             "Amount per recipient   :",
//             amountEach / 10 ** 18,
//             "tokens"
//         );
//         console.log(
//             "Approved amount        :",
//             totalAmount / 10 ** 18,
//             "tokens"
//         );

//         // Measure gas for the SINGLE transaction
//         uint256 gasBefore = gasleft();

//         // Execute SINGLE distribution call with all 1000 addresses
//         distributor.distributeToken(
//             address(token),
//             distributorAddress,
//             recipients,
//             amountEach
//         );

//         uint256 gasUsed = gasBefore - gasleft();

//         console.log("\n=== AFTER DISTRIBUTION ===");
//         console.log("Transaction status     : SUCCESS");
//         console.log("Total gas used         :", gasUsed);
//         console.log("Gas per recipient      :", gasUsed / RECIPIENTS_COUNT);
//         console.log(
//             "Distributor final bal  :",
//             token.balanceOf(distributorAddress) / 10 ** 18,
//             "tokens"
//         );
//         console.log(
//             "Tokens distributed     :",
//             (initialBalance - token.balanceOf(distributorAddress)) / 10 ** 18,
//             "tokens"
//         );

//         // Verify all 1000 recipients received exact tokens
//         console.log("\n=== VERIFICATION ===");
//         uint256 verifiedCount = 0;
//         for (uint256 i = 0; i < RECIPIENTS_COUNT; i++) {
//             uint256 balance = token.balanceOf(recipients[i]);
//             assertEq(
//                 balance,
//                 amountEach,
//                 string(
//                     abi.encodePacked(
//                         "Recipient ",
//                         vm.toString(i),
//                         " has incorrect balance"
//                     )
//                 )
//             );
//             verifiedCount++;
//         }
//         console.log(
//             "Recipients verified    :",
//             verifiedCount,
//             "/",
//             RECIPIENTS_COUNT
//         );

//         // Verify distributor balance decreased correctly
//         assertEq(
//             token.balanceOf(distributorAddress),
//             initialBalance - totalAmount,
//             "Distributor balance incorrect after distribution"
//         );

//         // Verify total tokens distributed
//         uint256 totalDistributed = 0;
//         for (uint256 i = 0; i < RECIPIENTS_COUNT; i++) {
//             totalDistributed += token.balanceOf(recipients[i]);
//         }
//         assertEq(
//             totalDistributed,
//             totalAmount,
//             "Total distributed amount mismatch"
//         );

//         console.log(
//             "Total distributed      :",
//             totalDistributed / 10 ** 18,
//             "tokens"
//         );
//         console.log(
//             "\nSUCCESS: All 1000 recipients received tokens in SINGLE transaction!"
//         );
//         console.log("No batching required");
//         console.log("All balances verified");

//         // Gas efficiency report
//         console.log("\n=== GAS EFFICIENCY REPORT ===");
//         console.log("Estimated tx cost @ 50 gwei:");
//         uint256 ethCost = (gasUsed * 50 gwei) / 1 ether;
//         console.log("  - ETH cost           : ~", ethCost, "ETH");
//         console.log(
//             "  - Cost per recipient : ~",
//             (gasUsed * 50) / RECIPIENTS_COUNT,
//             "gwei"
//         );

//         // Warning about block gas limits
//         if (gasUsed > 30_000_000) {
//             console.log(
//                 "\nWARNING: Gas used exceeds Ethereum block limit (30M gas)"
//             );
//             console.log("  This transaction would fail on Ethereum mainnet!");
//             console.log("  Consider using batching or L2 solutions.");
//         } else {
//             console.log("\nGas usage is within Ethereum block limit");
//         }
//     }

//     /**
//      * @notice Test distributing to 1000 addresses in a single transaction
//      */
//     function test_Distribute1000Addresses() public {
//         uint256 amountEach = 1_000 * 10 ** 18; // 1000 tokens each
//         uint256 totalAmount = amountEach * RECIPIENTS_COUNT; // 1 million tokens total

//         // Approve tokens from distributor address
//         vm.prank(distributorAddress);
//         token.approve(address(distributor), totalAmount);

//         // Check initial balances
//         uint256 initialBalance = token.balanceOf(distributorAddress);
//         console.log("\n=== Before Distribution ===");
//         console.log("Distributor balance:", initialBalance);
//         console.log("Total to distribute:", totalAmount);
//         console.log("Amount per recipient:", amountEach);

//         // Measure gas
//         uint256 gasBefore = gasleft();

//         // Execute distribution
//         distributor.distributeToken(
//             address(token),
//             distributorAddress,
//             recipients,
//             amountEach
//         );

//         uint256 gasUsed = gasBefore - gasleft();

//         console.log("\n=== After Distribution ===");
//         console.log("Gas used:", gasUsed);
//         console.log("Gas per recipient:", gasUsed / RECIPIENTS_COUNT);
//         console.log(
//             "Distributor balance:",
//             token.balanceOf(distributorAddress)
//         );

//         // Verify all recipients received tokens
//         for (uint256 i = 0; i < RECIPIENTS_COUNT; i++) {
//             assertEq(
//                 token.balanceOf(recipients[i]),
//                 amountEach,
//                 "Recipient did not receive correct amount"
//             );
//         }

//         // Verify distributor balance decreased
//         assertEq(
//             token.balanceOf(distributorAddress),
//             initialBalance - totalAmount,
//             "Distributor balance incorrect"
//         );

//         console.log("All 1000 recipients received tokens successfully");
//     }

//     /**
//      * @notice Test distributing in batches (200 addresses per transaction)
//      */
//     function test_DistributeInBatches() public {
//         uint256 amountEach = 1_000 * 10 ** 18; // 1000 tokens each
//         uint256 totalAmount = amountEach * RECIPIENTS_COUNT;
//         uint256 batchSize = 200;
//         uint256 batches = RECIPIENTS_COUNT / batchSize;

//         // Approve total amount
//         vm.prank(distributorAddress);
//         token.approve(address(distributor), totalAmount);

//         console.log("\n=== Batch Distribution ===");
//         console.log("Total recipients:", RECIPIENTS_COUNT);
//         console.log("Batch size:", batchSize);
//         console.log("Number of batches:", batches);

//         uint256 totalGasUsed = 0;

//         for (uint256 batch = 0; batch < batches; batch++) {
//             uint256 start = batch * batchSize;

//             // Create batch array
//             address[] memory batchRecipients = new address[](batchSize);
//             for (uint256 i = 0; i < batchSize; i++) {
//                 batchRecipients[i] = recipients[start + i];
//             }

//             // Measure gas for this batch
//             uint256 gasBefore = gasleft();

//             // Execute batch distribution
//             distributor.distributeToken(
//                 address(token),
//                 distributorAddress,
//                 batchRecipients,
//                 amountEach
//             );

//             uint256 gasUsed = gasBefore - gasleft();
//             totalGasUsed += gasUsed;

//             console.log("Batch", batch + 1, "- Gas used:", gasUsed);
//         }

//         console.log("\n=== Batch Summary ===");
//         console.log("Total gas used:", totalGasUsed);
//         console.log("Average gas per batch:", totalGasUsed / batches);
//         console.log(
//             "Average gas per recipient:",
//             totalGasUsed / RECIPIENTS_COUNT
//         );

//         // Verify all recipients received tokens
//         for (uint256 i = 0; i < RECIPIENTS_COUNT; i++) {
//             assertEq(
//                 token.balanceOf(recipients[i]),
//                 amountEach,
//                 "Recipient did not receive correct amount"
//             );
//         }

//         console.log("All batches completed successfully");
//     }

//     /**
//      * @notice Test with insufficient balance
//      */
//     function test_RevertInsufficientBalance() public {
//         uint256 amountEach = INITIAL_SUPPLY * 2; // More than available per recipient

//         vm.prank(distributorAddress);
//         token.approve(address(distributor), type(uint256).max);

//         vm.expectRevert(TokenDistributor.InsufficientBalance.selector);
//         distributor.distributeToken(
//             address(token),
//             distributorAddress,
//             recipients,
//             amountEach
//         );

//         console.log("Correctly reverted on insufficient balance");
//     }

//     /**
//      * @notice Test with empty recipients array
//      */
//     function test_RevertEmptyRecipients() public {
//         address[] memory emptyRecipients = new address[](0);
//         uint256 amountEach = 1000 * 10 ** 18;

//         vm.expectRevert(TokenDistributor.InvalidRecipients.selector);
//         distributor.distributeToken(
//             address(token),
//             distributorAddress,
//             emptyRecipients,
//             amountEach
//         );

//         console.log("Correctly reverted on empty recipients");
//     }

//     /**
//      * @notice Test with zero address in recipients
//      */
//     function test_RevertZeroAddress() public {
//         address[] memory badRecipients = new address[](3);
//         badRecipients[0] = address(0x1111);
//         badRecipients[1] = address(0); // Zero address
//         badRecipients[2] = address(0x3333);

//         uint256 amountEach = 1000 * 10 ** 18;
//         uint256 totalAmount = amountEach * 3;

//         vm.prank(distributorAddress);
//         token.approve(address(distributor), totalAmount);

//         vm.expectRevert(TokenDistributor.InvalidRecipients.selector);
//         distributor.distributeToken(
//             address(token),
//             distributorAddress,
//             badRecipients,
//             amountEach
//         );

//         console.log("Correctly reverted on zero address");
//     }

//     /**
//      * @notice Test gas usage comparison for different batch sizes
//      */
//     function test_GasComparisonBatchSizes() public {
//         uint256 amountEach = 1234 * 10 ** 18;
//         uint256 totalAmount = amountEach * RECIPIENTS_COUNT;
//         uint256[] memory batchSizes = new uint256[](5);
//         batchSizes[0] = 50;
//         batchSizes[1] = 100;
//         batchSizes[2] = 200;
//         batchSizes[3] = 500;
//         batchSizes[4] = 1000;

//         console.log("\n=== Gas Comparison for Different Batch Sizes ===");

//         uint256 minGas = type(uint256).max;
//         uint256 minBatchSize = 0;

//         for (uint256 idx = 0; idx < batchSizes.length; idx++) {
//             // Reset state for each test
//             setUp();

//             uint256 batchSize = batchSizes[idx];

//             vm.prank(distributorAddress);
//             token.approve(address(distributor), totalAmount);

//             uint256 gasUsed = _distributeBatchSize(batchSize, amountEach);

//             // Track lowest gas usage
//             if (gasUsed < minGas) {
//                 minGas = gasUsed;
//                 minBatchSize = batchSize;
//             }
//         }

//         console.log("\n=== Lowest gas usage ===");
//         console.log(
//             "Batch size with least gas:",
//             minBatchSize,
//             "- Gas used:",
//             minGas
//         );
//     }

//     /**
//      * @notice Helper function to distribute tokens with a given batch size
//      */
//     function _distributeBatchSize(
//         uint256 batchSize,
//         uint256 amountEach
//     ) internal returns (uint256 gasUsed) {
//         if (batchSize == 1000) {
//             // Single batch
//             uint256 gasBefore = gasleft();
//             distributor.distributeToken(
//                 address(token),
//                 distributorAddress,
//                 recipients,
//                 amountEach
//             );
//             gasUsed = gasBefore - gasleft();
//             console.log(
//                 "Batch size:",
//                 batchSize,
//                 "(single tx) - Gas:",
//                 gasUsed
//             );
//         } else {
//             // Multiple batches
//             uint256 batches = RECIPIENTS_COUNT / batchSize;
//             uint256 totalGas = 0;

//             for (uint256 batch = 0; batch < batches; batch++) {
//                 address[] memory batchRecipients = new address[](batchSize);
//                 for (uint256 i = 0; i < batchSize; i++) {
//                     batchRecipients[i] = recipients[batch * batchSize + i];
//                 }

//                 uint256 gasBefore = gasleft();
//                 distributor.distributeToken(
//                     address(token),
//                     distributorAddress,
//                     batchRecipients,
//                     amountEach
//                 );
//                 totalGas += (gasBefore - gasleft());
//             }

//             gasUsed = totalGas;
//             console.log("Batch size:", batchSize);
//             console.log("Total gas:", totalGas);
//             console.log("Batches:", batches);
//         }
//     }
// }
