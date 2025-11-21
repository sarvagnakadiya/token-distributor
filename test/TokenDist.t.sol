// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {TokenDistributor} from "../src/TokenDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TokenDistributorTest is Test {
    TokenDistributor public distributor;
    ERC20Mock public token;

    address public owner = address(1);
    address public admin = address(2);
    address public distributor_account = address(3);
    address public recipient1 = address(4);
    address public recipient2 = address(5);
    address public recipient3 = address(6);

    uint256 constant INITIAL_BALANCE = 1_000_000 * 10 ** 18;

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
        // Deploy mock token
        token = new ERC20Mock();

        // Deploy distributor contract
        vm.prank(owner);
        distributor = new TokenDistributor(owner, admin);

        // Mint tokens to distributor account
        token.mint(distributor_account, INITIAL_BALANCE);
    }

    function test_Constructor() public view {
        assertEq(distributor.owner(), owner);
        assertEq(distributor.admin(), admin);
    }

    function test_RevertWhen_ConstructorWithZeroAdmin() public {
        vm.prank(owner);
        vm.expectRevert(TokenDistributor.InvalidAdmin.selector);
        new TokenDistributor(owner, address(0));
    }

    function test_DistributeToken() public {
        uint256 amountEach = 1000 * 10 ** 18;
        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;

        uint256 totalDistribution = amountEach * 3;
        uint256 feeAmount = (totalDistribution * 100) / 10000; // 1%
        uint256 totalRequired = totalDistribution + feeAmount;

        // Approve distributor contract
        vm.prank(distributor_account);
        token.approve(address(distributor), totalRequired);

        // Record balances before
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 distributorBalanceBefore = token.balanceOf(distributor_account);

        // Distribute tokens
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(address(token), owner, feeAmount);
        vm.expectEmit(true, true, false, true);
        emit TokensDistributed(
            address(token),
            distributor_account,
            3,
            amountEach,
            totalDistribution,
            feeAmount
        );
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );

        // Check balances after
        assertEq(token.balanceOf(owner), ownerBalanceBefore + feeAmount);
        assertEq(
            token.balanceOf(distributor_account),
            distributorBalanceBefore - totalRequired
        );
        assertEq(token.balanceOf(recipient1), amountEach);
        assertEq(token.balanceOf(recipient2), amountEach);
        assertEq(token.balanceOf(recipient3), amountEach);
    }

    function test_RevertWhen_NotAdmin() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        vm.prank(owner);
        vm.expectRevert(TokenDistributor.NotAdmin.selector);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            100
        );
    }

    function test_RevertWhen_EmptyRecipients() public {
        address[] memory recipients = new address[](0);

        vm.prank(admin);
        vm.expectRevert(TokenDistributor.InvalidRecipients.selector);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            100
        );
    }

    function test_RevertWhen_RecipientIsZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = address(0);

        uint256 amountEach = 100 * 10 ** 18;
        uint256 totalRequired = (amountEach * 2) +
            ((amountEach * 2 * 100) / 10000);

        vm.prank(distributor_account);
        token.approve(address(distributor), totalRequired);

        vm.prank(admin);
        vm.expectRevert(TokenDistributor.InvalidRecipients.selector);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );
    }

    function test_RevertWhen_InsufficientBalance() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256 amountEach = INITIAL_BALANCE + 1;

        vm.prank(admin);
        vm.expectRevert(TokenDistributor.InsufficientBalance.selector);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );
    }

    function test_RevertWhen_InsufficientAllowance() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256 amountEach = 1000 * 10 ** 18;
        uint256 totalRequired = amountEach + ((amountEach * 100) / 10000);

        // Approve less than required
        vm.prank(distributor_account);
        token.approve(address(distributor), totalRequired - 1);

        vm.prank(admin);
        vm.expectRevert(TokenDistributor.InsufficientAllowance.selector);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );
    }

    function test_SetAdmin() public {
        address newAdmin = address(7);

        vm.prank(owner);
        distributor.setAdmin(newAdmin);

        assertEq(distributor.admin(), newAdmin);
    }

    function test_RevertWhen_SetAdminWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TokenDistributor.InvalidAdmin.selector);
        distributor.setAdmin(address(0));
    }

    function test_RevertWhen_SetAdminNotOwner() public {
        address newAdmin = address(7);

        vm.prank(admin);
        vm.expectRevert();
        distributor.setAdmin(newAdmin);
    }

    function test_FeeCalculation() public {
        uint256 amountEach = 10000 * 10 ** 18;
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256 totalDistribution = amountEach;
        uint256 expectedFee = (totalDistribution * 100) / 10000; // 1% = 100 tokens
        uint256 totalRequired = totalDistribution + expectedFee;

        vm.prank(distributor_account);
        token.approve(address(distributor), totalRequired);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );

        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 actualFee = ownerBalanceAfter - ownerBalanceBefore;

        assertEq(actualFee, expectedFee);
        assertEq(actualFee, 100 * 10 ** 18); // Should be exactly 100 tokens
    }

    function testFuzz_DistributeToken(
        uint8 recipientCount,
        uint96 amountEach
    ) public {
        vm.assume(recipientCount > 0 && recipientCount <= 100);
        vm.assume(
            amountEach > 0 && amountEach < INITIAL_BALANCE / recipientCount
        );

        address[] memory recipients = new address[](recipientCount);
        for (uint256 i = 0; i < recipientCount; i++) {
            recipients[i] = address(uint160(1000 + i));
        }

        uint256 totalDistribution = uint256(amountEach) * recipientCount;
        uint256 feeAmount = (totalDistribution * 100) / 10000;
        uint256 totalRequired = totalDistribution + feeAmount;

        vm.prank(distributor_account);
        token.approve(address(distributor), totalRequired);

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributor_account,
            recipients,
            amountEach
        );

        // Verify all recipients received correct amount
        for (uint256 i = 0; i < recipientCount; i++) {
            assertEq(token.balanceOf(recipients[i]), amountEach);
        }

        // Verify fee was collected
        assertEq(token.balanceOf(owner), feeAmount);
    }
}
