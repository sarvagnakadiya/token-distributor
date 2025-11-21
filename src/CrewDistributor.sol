// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CrewDistributor is Ownable {
    error InvalidRecipients();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DistributionFailed();
    error NotAdmin();
    error InvalidAddress();
    error InvalidValues();

    address public admin;
    address public feeRecipient;

    event TokensDistributed(
        address indexed token,
        address indexed distributor,
        address indexed feeRecipient,
        uint256 recipientCount,
        uint256 totalDistributed,
        uint256 feeAmount
    );

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(
        address _owner,
        address _admin,
        address _feeRecipient
    ) Ownable(_owner) {
        admin = _admin;
        feeRecipient = _feeRecipient;
    }

    function distributeToken(
        address _token,
        address _distributor,
        address[] calldata _recipients,
        uint256[] calldata _values,
        uint256 _feeAmount
    ) external onlyAdmin {
        uint256 length = _recipients.length;
        if (length == 0) revert InvalidRecipients();
        if (length != _values.length) revert InvalidValues();

        IERC20 token = IERC20(_token);

        uint256 totalValues;

        // Sum of all values
        for (uint256 i; i < length; ) {
            totalValues += _values[i];
            unchecked {
                ++i;
            }
        }

        uint256 totalRequired = totalValues + _feeAmount;

        // check allowance + balance
        if (token.balanceOf(_distributor) < totalRequired)
            revert InsufficientBalance();
        if (token.allowance(_distributor, address(this)) < totalRequired)
            revert InsufficientAllowance();

        // pull fee first
        if (_feeAmount > 0) {
            if (!token.transferFrom(_distributor, feeRecipient, _feeAmount)) {
                revert DistributionFailed();
            }
        }

        uint256 totalSent;

        // Distribute exact values
        for (uint256 i; i < length; ) {
            address recipient = _recipients[i];
            if (recipient == address(0)) revert InvalidRecipients();

            uint256 amount = _values[i];

            if (!token.transferFrom(_distributor, recipient, amount)) {
                revert DistributionFailed();
            }

            totalSent += amount;

            unchecked {
                ++i;
            }
        }
        emit TokensDistributed(
            _token,
            _distributor,
            feeRecipient,
            length,
            totalSent,
            _feeAmount
        );
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) revert InvalidAddress();
        admin = _newAdmin;
    }

    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        if (_newFeeRecipient == address(0)) revert InvalidAddress();
        feeRecipient = _newFeeRecipient;
    }
}
