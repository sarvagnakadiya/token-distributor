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
        uint256 _amountEach
    ) external onlyAdmin {
        uint256 length = _recipients.length;
        if (length == 0) revert InvalidRecipients();

        uint256 totalDistribution = _amountEach * length;

        // Calculate fee (fixed 1%)
        uint256 feeAmount = (totalDistribution * 100) / 10000;
        uint256 totalRequired = totalDistribution + feeAmount;

        IERC20 token = IERC20(_token);

        if (token.balanceOf(_distributor) < totalRequired)
            revert InsufficientBalance();
        if (token.allowance(_distributor, address(this)) < totalRequired)
            revert InsufficientAllowance();

        // Transfer fee to fee recipient first
        if (!token.transferFrom(_distributor, owner(), feeAmount)) {
            revert DistributionFailed();
        }
        emit FeeCollected(_token, owner(), feeAmount);

        // Distribute to recipients
        for (uint256 i; i < length; ) {
            address recipient = _recipients[i];
            if (recipient == address(0)) revert InvalidRecipients();

            if (!token.transferFrom(_distributor, recipient, _amountEach)) {
                revert DistributionFailed();
            }

            // gas optimization
            unchecked {
                ++i;
            }
        }
        emit TokensDistributed(
            _token,
            _distributor,
            length,
            _amountEach,
            totalDistribution,
            feeAmount
        );
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) revert InvalidAdmin();
        admin = _newAdmin;
    }
}
