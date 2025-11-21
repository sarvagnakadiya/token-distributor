// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CrewDistributor} from "../src/CrewDistributor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrewDistributortest is Test {
    CrewDistributor public distributor;
    ERC20Mock public token;

    address public owner;
    address public admin;
    address public feeRecipient;
    address public distributorAddress;
    address public recipient1;
    address public recipient2;
    address public recipient3;
    address public user;

    event TokensDistributed(
        address indexed token,
        address indexed distributor,
        address indexed feeRecipient,
        uint256 recipientCount,
        uint256 totalDistributed,
        uint256 feeAmount
    );

    function setUp() public {
        owner = address(1);
        admin = address(2);
        feeRecipient = address(3);
        distributorAddress = address(4);
        recipient1 = address(5);
        recipient2 = address(6);
        recipient3 = address(7);
        user = address(8);

        vm.prank(owner);
        distributor = new CrewDistributor(owner, admin, feeRecipient);

        token = new ERC20Mock();
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsCorrectValues() public view {
        assertEq(distributor.owner(), owner);
        assertEq(distributor.admin(), admin);
        assertEq(distributor.feeRecipient(), feeRecipient);
    }

    // ============ distributeToken Tests ============

    function test_DistributeToken_Success_WithFee() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 feeAmount = 50e18;
        uint256 totalRequired = amount1 + amount2 + feeAmount;

        // Setup: mint tokens to distributor and approve
        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        // Check initial balances
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(feeRecipient), 0);

        // Execute distribution
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TokensDistributed(
            address(token),
            distributorAddress,
            feeRecipient,
            2,
            amount1 + amount2,
            feeAmount
        );
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        // Verify balances
        assertEq(token.balanceOf(recipient1), amount1);
        assertEq(token.balanceOf(recipient2), amount2);
        assertEq(token.balanceOf(feeRecipient), feeAmount);
        assertEq(token.balanceOf(distributorAddress), 0);
    }

    function test_DistributeToken_Success_WithoutFee() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 feeAmount = 0;
        uint256 totalRequired = amount1 + amount2;

        // Setup: mint tokens to distributor and approve
        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        // Execute distribution
        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        // Verify balances
        assertEq(token.balanceOf(recipient1), amount1);
        assertEq(token.balanceOf(recipient2), amount2);
        assertEq(token.balanceOf(feeRecipient), 0);
    }

    function test_DistributeToken_Success_SingleRecipient() public {
        uint256 amount = 100e18;
        uint256 feeAmount = 10e18;
        uint256 totalRequired = amount + feeAmount;

        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        assertEq(token.balanceOf(recipient1), amount);
        assertEq(token.balanceOf(feeRecipient), feeAmount);
    }

    function test_DistributeToken_Success_MultipleRecipients() public {
        uint256 amount1 = 50e18;
        uint256 amount2 = 100e18;
        uint256 amount3 = 150e18;
        uint256 feeAmount = 20e18;
        uint256 totalRequired = amount1 + amount2 + amount3 + feeAmount;

        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;

        uint256[] memory values = new uint256[](3);
        values[0] = amount1;
        values[1] = amount2;
        values[2] = amount3;

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        assertEq(token.balanceOf(recipient1), amount1);
        assertEq(token.balanceOf(recipient2), amount2);
        assertEq(token.balanceOf(recipient3), amount3);
        assertEq(token.balanceOf(feeRecipient), feeAmount);
    }

    function test_DistributeToken_Revert_NotAdmin() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;

        vm.prank(user);
        vm.expectRevert(CrewDistributor.NotAdmin.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_EmptyRecipients() public {
        address[] memory recipients = new address[](0);
        uint256[] memory values = new uint256[](0);

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InvalidRecipients.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_MismatchedArrays() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InvalidValues.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_ZeroAddressRecipient() public {
        uint256 amount = 100e18;
        token.mint(distributorAddress, amount);
        vm.prank(distributorAddress);
        token.approve(address(distributor), amount);

        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InvalidRecipients.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_InsufficientBalance() public {
        uint256 amount = 100e18;
        uint256 mintedAmount = 50e18; // Less than required

        token.mint(distributorAddress, mintedAmount);
        vm.prank(distributorAddress);
        token.approve(address(distributor), amount);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InsufficientBalance.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_InsufficientAllowance() public {
        uint256 amount = 100e18;
        uint256 approvedAmount = 50e18; // Less than required

        token.mint(distributorAddress, amount);
        vm.prank(distributorAddress);
        token.approve(address(distributor), approvedAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InsufficientAllowance.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            0
        );
    }

    function test_DistributeToken_Revert_InsufficientBalance_WithFee() public {
        uint256 amount = 100e18;
        uint256 feeAmount = 50e18;
        uint256 totalRequired = amount + feeAmount;
        uint256 mintedAmount = 120e18; // Less than total required

        token.mint(distributorAddress, mintedAmount);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InsufficientBalance.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );
    }

    function test_DistributeToken_Revert_InsufficientAllowance_WithFee()
        public
    {
        uint256 amount = 100e18;
        uint256 feeAmount = 50e18;
        uint256 totalRequired = amount + feeAmount;
        uint256 approvedAmount = 120e18; // Less than total required

        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), approvedAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        vm.expectRevert(CrewDistributor.InsufficientAllowance.selector);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );
    }

    // ============ setAdmin Tests ============

    function test_SetAdmin_Success() public {
        address newAdmin = address(9);

        vm.prank(owner);
        distributor.setAdmin(newAdmin);

        assertEq(distributor.admin(), newAdmin);
    }

    function test_SetAdmin_Revert_NotOwner() public {
        address newAdmin = address(9);

        vm.prank(user);
        vm.expectRevert();
        distributor.setAdmin(newAdmin);
    }

    function test_SetAdmin_Revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(CrewDistributor.InvalidAddress.selector);
        distributor.setAdmin(address(0));
    }

    // ============ setFeeRecipient Tests ============

    function test_SetFeeRecipient_Success() public {
        address newFeeRecipient = address(10);

        vm.prank(owner);
        distributor.setFeeRecipient(newFeeRecipient);

        assertEq(distributor.feeRecipient(), newFeeRecipient);
    }

    function test_SetFeeRecipient_Revert_NotOwner() public {
        address newFeeRecipient = address(10);

        vm.prank(user);
        vm.expectRevert();
        distributor.setFeeRecipient(newFeeRecipient);
    }

    function test_SetFeeRecipient_Revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(CrewDistributor.InvalidAddress.selector);
        distributor.setFeeRecipient(address(0));
    }

    // ============ Edge Cases ============

    function test_DistributeToken_WithZeroValues() public {
        uint256 amount1 = 0;
        uint256 amount2 = 0;
        uint256 feeAmount = 0;

        token.mint(distributorAddress, 1e18); // Mint some tokens
        vm.prank(distributorAddress);
        token.approve(address(distributor), 1e18);

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(feeRecipient), 0);
    }

    function test_DistributeToken_WithLargeAmounts() public {
        uint256 amount = type(uint256).max / 2; // Large amount
        uint256 feeAmount = 1e18;

        // Note: This test may fail if the token doesn't support such large amounts
        // In practice, you'd need to ensure the token can handle this
        token.mint(distributorAddress, amount + feeAmount);
        vm.prank(distributorAddress);
        token.approve(address(distributor), amount + feeAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;

        uint256[] memory values = new uint256[](1);
        values[0] = amount;

        vm.prank(admin);
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );

        assertEq(token.balanceOf(recipient1), amount);
        assertEq(token.balanceOf(feeRecipient), feeAmount);
    }

    function test_DistributeToken_EventEmitted() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 feeAmount = 50e18;
        uint256 totalRequired = amount1 + amount2 + feeAmount;

        token.mint(distributorAddress, totalRequired);
        vm.prank(distributorAddress);
        token.approve(address(distributor), totalRequired);

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TokensDistributed(
            address(token),
            distributorAddress,
            feeRecipient,
            2,
            amount1 + amount2,
            feeAmount
        );
        distributor.distributeToken(
            address(token),
            distributorAddress,
            recipients,
            values,
            feeAmount
        );
    }
}
