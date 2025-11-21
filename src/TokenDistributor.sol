// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenDistributor is Ownable {
    error InvalidRecipients();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DistributionFailed();
    error NotAdmin();
    error InvalidFeeRecipient();
    error InvalidAdmin();

    address public admin;

    // events
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

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address _owner, address _admin) Ownable(_owner) {
        if (_admin == address(0)) revert InvalidAdmin();
        admin = _admin;
    }

    function distributeToken(
        address _token,
        address _distributor,
        address[] calldata _recipients,
        uint256 _totalAmount
    ) external onlyAdmin {
        uint256 length = _recipients.length;
        if (length == 0) revert InvalidRecipients();

        // Calculate fee (1%) from total amount
        uint256 feeAmount = (_totalAmount * 100) / 10000;

        // Amount available for distribution after fee
        uint256 amountAfterFee = _totalAmount - feeAmount;

        // Calculate amount per recipient (floor division)
        uint256 amountEach = amountAfterFee / length;
        uint256 totalDistribution = amountEach * length;

        // Dust from floor division (goes to owner)
        uint256 dust = amountAfterFee - totalDistribution;

        IERC20 token = IERC20(_token);

        // User only needs to provide exactly _totalAmount
        if (token.balanceOf(_distributor) < _totalAmount)
            revert InsufficientBalance();
        if (token.allowance(_distributor, address(this)) < _totalAmount)
            revert InsufficientAllowance();

        // Transfer fee to owner first
        if (!token.transferFrom(_distributor, owner(), feeAmount)) {
            revert DistributionFailed();
        }
        emit FeeCollected(_token, owner(), feeAmount);

        // Distribute to recipients
        for (uint256 i; i < length; ) {
            address recipient = _recipients[i];
            if (recipient == address(0)) revert InvalidRecipients();

            if (!token.transferFrom(_distributor, recipient, amountEach)) {
                revert DistributionFailed();
            }

            // gas optimization
            unchecked {
                ++i;
            }
        }

        // Transfer dust to owner (remainder from floor division)
        if (dust > 0) {
            if (!token.transferFrom(_distributor, owner(), dust)) {
                revert DistributionFailed();
            }
        }

        emit TokensDistributed(
            _token,
            _distributor,
            length,
            amountEach,
            totalDistribution,
            feeAmount
        );
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) revert InvalidAdmin();
        admin = _newAdmin;
    }
}
