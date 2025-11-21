// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {TokenDistributor} from "../src/TokenDistributor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TokenDistributorTest is Test {
    TokenDistributor public distributor;
    ERC20Mock public token;

    address public owner = makeAddr("owner");
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");

    event FeeCollected(
        address indexed token,
        address indexed feeRecipient,
        uint256 feeAmount
    );

    event TokensDistributed(
        address indexed token,
        address indexed distributor,
        uint256 recipientCount,
        uint256 amountEach,
        uint256 totalDistributed,
        uint256 feeAmount
    );

    function setUp() public {
        vm.startPrank(owner);
        distributor = new TokenDistributor(owner, admin);
        token = new ERC20Mock();
        vm.stopPrank();
    }

    function test_DustAccumulation_SmallAmount() public {
        // Create recipients
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");

        // Use 100 tokens total
        uint256 totalAmount = 100 ether;

        // Fee calculation: 1% of total
        uint256 expectedFee = (totalAmount * 100) / 10000; // 1 ether

        // Amount available for distribution
        uint256 amountAfterFee = totalAmount - expectedFee; // 99 ether

        // Distribution calculation
        uint256 expectedAmountEach = amountAfterFee / 3; // 33 ether
        uint256 expectedTotalDistributed = expectedAmountEach * 3; // 99 ether
        uint256 expectedDust = amountAfterFee - expectedTotalDistributed; // 0 ether

        // Mint tokens to user and approve (user only needs totalAmount)
        token.mint(user, totalAmount);
        vm.prank(user);
        token.approve(address(distributor), totalAmount);

        // Get owner balance before
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        // Distribute
        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            user,
            recipients,
            totalAmount
        );

        // Check what owner received (fee + dust)
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 ownerReceived = ownerBalanceAfter - ownerBalanceBefore;

        console2.log("=== Small Amount Test ===");
        console2.log("Total Amount:", totalAmount);
        console2.log("Fee (1%):", expectedFee);
        console2.log("Amount After Fee:", amountAfterFee);
        console2.log("Amount Each:", expectedAmountEach);
        console2.log("Total Distributed:", expectedTotalDistributed);
        console2.log("Dust:", expectedDust);
        console2.log("Owner Received:", ownerReceived);

        assertEq(
            ownerReceived,
            expectedDust + expectedFee,
            "Owner should receive dust + fee"
        );
        assertEq(token.balanceOf(recipients[0]), expectedAmountEach);
        assertEq(token.balanceOf(recipients[1]), expectedAmountEach);
        assertEq(token.balanceOf(recipients[2]), expectedAmountEach);
        assertEq(token.balanceOf(user), 0, "User should have 0 tokens left");
    }

    function test_DustAccumulation_LargeRecipientCount() public {
        // 1000 tokens for 7 recipients
        uint256 recipientCount = 7;
        address[] memory recipients = new address[](recipientCount);
        for (uint256 i = 0; i < recipientCount; i++) {
            recipients[i] = makeAddr(string(abi.encodePacked("recipient", i)));
        }

        uint256 totalAmount = 1000 ether;
        uint256 expectedFee = (totalAmount * 100) / 10000; // 10 ether
        uint256 amountAfterFee = totalAmount - expectedFee; // 990 ether
        uint256 expectedAmountEach = amountAfterFee / recipientCount; // 141.428... = 141 ether
        uint256 expectedTotalDistributed = expectedAmountEach * recipientCount; // 987 ether
        uint256 expectedDust = amountAfterFee - expectedTotalDistributed; // 3 ether

        // Mint and approve
        token.mint(user, totalAmount);
        vm.prank(user);
        token.approve(address(distributor), totalAmount);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        // Distribute
        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            user,
            recipients,
            totalAmount
        );

        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 ownerReceived = ownerBalanceAfter - ownerBalanceBefore;

        console2.log("=== Large Recipient Count Test ===");
        console2.log("Recipients:", recipientCount);
        console2.log("Total Amount:", totalAmount);
        console2.log("Fee (1%):", expectedFee);
        console2.log("Amount After Fee:", amountAfterFee);
        console2.log("Amount Each:", expectedAmountEach);
        console2.log("Total Distributed:", expectedTotalDistributed);
        console2.log("Dust:", expectedDust);
        console2.log("Owner Received:", ownerReceived);

        assertEq(ownerReceived, expectedDust + expectedFee);

        // Verify each recipient got correct amount
        for (uint256 i = 0; i < recipientCount; i++) {
            assertEq(token.balanceOf(recipients[i]), expectedAmountEach);
        }
    }

    function test_DustAccumulation_MultipleDistributions() public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        // First distribution: 100 tokens
        uint256 amount1 = 100 ether;
        uint256 fee1 = (amount1 * 100) / 10000; // 1 ether
        uint256 afterFee1 = amount1 - fee1; // 99 ether
        uint256 amountEach1 = afterFee1 / 3; // 33 ether
        uint256 dust1 = afterFee1 - (amountEach1 * 3); // 0 ether

        token.mint(user, amount1);
        vm.prank(user);
        token.approve(address(distributor), amount1);

        vm.prank(admin);
        distributor.distributeToken(address(token), user, recipients, amount1);

        // Second distribution: 200 tokens
        uint256 amount2 = 200 ether;
        uint256 fee2 = (amount2 * 100) / 10000; // 2 ether
        uint256 afterFee2 = amount2 - fee2; // 198 ether
        uint256 amountEach2 = afterFee2 / 3; // 66 ether
        uint256 dust2 = afterFee2 - (amountEach2 * 3); // 0 ether

        token.mint(user, amount2);
        vm.prank(user);
        token.approve(address(distributor), amount2);

        vm.prank(admin);
        distributor.distributeToken(address(token), user, recipients, amount2);

        // Calculate expected dust and fees
        uint256 expectedTotalDust = dust1 + dust2; // 0
        uint256 expectedTotalFee = fee1 + fee2; // 3 ether

        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 totalOwnerReceived = ownerBalanceAfter - ownerBalanceBefore;

        console2.log("=== Multiple Distributions Test ===");
        console2.log("Total Dust Accumulated:", expectedTotalDust);
        console2.log("Total Fees Collected:", expectedTotalFee);
        console2.log("Total Owner Received:", totalOwnerReceived);

        assertEq(totalOwnerReceived, expectedTotalDust + expectedTotalFee);
    }

    function test_NoDust_PerfectDivision() public {
        address[] memory recipients = new address[](4);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");
        recipients[3] = makeAddr("recipient4");

        // 100 tokens total
        uint256 totalAmount = 100 ether;
        uint256 expectedFee = (totalAmount * 100) / 10000; // 1 ether
        uint256 amountAfterFee = totalAmount - expectedFee; // 99 ether
        uint256 expectedAmountEach = amountAfterFee / 4; // 24.75 = 24 ether (floor)
        uint256 expectedTotalDistributed = expectedAmountEach * 4; // 96 ether
        uint256 expectedDust = amountAfterFee - expectedTotalDistributed; // 3 ether

        token.mint(user, totalAmount);
        vm.prank(user);
        token.approve(address(distributor), totalAmount);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            user,
            recipients,
            totalAmount
        );

        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 ownerReceived = ownerBalanceAfter - ownerBalanceBefore;

        console2.log("=== Perfect Division Test ===");
        console2.log("Total Amount:", totalAmount);
        console2.log("Fee:", expectedFee);
        console2.log("After Fee:", amountAfterFee);
        console2.log("Amount Each:", expectedAmountEach);
        console2.log("Dust:", expectedDust);
        console2.log("Owner Received:", ownerReceived);

        assertEq(ownerReceived, expectedFee + expectedDust);
    }

    function testFuzz_DustAlwaysAccountedFor(
        uint256 totalAmount,
        uint8 recipientCount
    ) public {
        // Bound inputs
        totalAmount = bound(totalAmount, 1 ether, 1_000_000 ether);
        recipientCount = uint8(bound(recipientCount, 1, 100));

        // Calculate what will happen
        uint256 fee = (totalAmount * 100) / 10000;
        uint256 amountAfterFee = totalAmount - fee;
        uint256 amountEach = amountAfterFee / recipientCount;
        uint256 totalDistributed = amountEach * recipientCount;
        uint256 dust = amountAfterFee - totalDistributed;

        // Create recipients
        address[] memory recipients = new address[](recipientCount);
        for (uint256 i = 0; i < recipientCount; i++) {
            recipients[i] = makeAddr(
                string(abi.encodePacked("fuzzRecipient", i))
            );
        }

        // Mint and approve exactly totalAmount
        token.mint(user, totalAmount);
        vm.prank(user);
        token.approve(address(distributor), totalAmount);

        uint256 userBalanceBefore = token.balanceOf(user);
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        // Distribute
        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            user,
            recipients,
            totalAmount
        );

        // Verify all tokens are accounted for
        uint256 userBalanceAfter = token.balanceOf(user);
        uint256 ownerBalanceAfter = token.balanceOf(owner);

        uint256 totalRecipientsReceived = 0;
        for (uint256 i = 0; i < recipientCount; i++) {
            totalRecipientsReceived += token.balanceOf(recipients[i]);
        }

        uint256 ownerReceived = ownerBalanceAfter - ownerBalanceBefore;
        uint256 userSpent = userBalanceBefore - userBalanceAfter;

        // All tokens distributed should equal what user spent
        assertEq(
            totalRecipientsReceived + ownerReceived,
            userSpent,
            "All tokens must be accounted for"
        );
        assertEq(
            ownerReceived,
            dust + fee,
            "Owner should receive exactly dust + fee"
        );
        assertEq(
            userSpent,
            totalAmount,
            "User should spend exactly totalAmount"
        );
        assertEq(userBalanceAfter, 0, "User should have 0 tokens left");
    }

    function test_Events_DustAndFee() public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");

        uint256 totalAmount = 100 ether;
        uint256 fee = (totalAmount * 100) / 10000; // 1 ether
        uint256 amountAfterFee = totalAmount - fee; // 99 ether
        uint256 amountEach = amountAfterFee / 3; // 33 ether
        uint256 totalDistributed = amountEach * 3; // 99 ether

        token.mint(user, totalAmount);
        vm.prank(user);
        token.approve(address(distributor), totalAmount);

        // Expect FeeCollected event
        vm.expectEmit(true, true, true, true);
        emit FeeCollected(address(token), owner, fee);

        // Expect TokensDistributed event
        vm.expectEmit(true, true, true, true);
        emit TokensDistributed(
            address(token),
            user,
            3,
            amountEach,
            totalDistributed,
            fee
        );

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            user,
            recipients,
            totalAmount
        );
    }
}
