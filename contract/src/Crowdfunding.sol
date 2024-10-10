// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CampaignBase} from "./CampaignBase.sol";

/// @title Crowdfunding
/// @author Olaleye Blessing
/// @notice Main contract for crowdfunding functionality, extending CampaignBase
/// @dev Implements donation and refund mechanisms
contract Crowdfunding is CampaignBase {
    /// @notice Emitted when a new donation is made to a campaign
    /// @param donor The address of the donor
    /// @param campaignId The ID of the campaign receiving the donation
    /// @param amount The amount donated
    event NewDonation(address indexed donor, uint256 indexed campaignId, uint256 amount);

    /// @notice Emitted when a donation is refunded
    /// @param donor The address of the donor receiving the refund
    /// @param campaignId The ID of the campaign from which the refund is made
    /// @param amount The amount refunded
    event DonationRefunded(address indexed donor, uint256 indexed campaignId, uint256 amount);

    /// @notice Error thrown when donor has no donation
    error Crowdfunding__NoDonationFound(uint256 campaignId);

    /// @notice Error thrown when attempting to refund more than the donor has contributed
    error Crowdfunding__InsufficientDonation(uint256 campaignId, uint256 amountToRefund, uint256 amountDonated);

    /// @notice Error thrown when a refund transaction fails
    error Crowdfunding__RefundFailed(uint256 campaignId);

    constructor(address _crowdchainTokenAddress) CampaignBase(_crowdchainTokenAddress) {}

    /// @notice Retrieves the list of donors and their contributions for a specific campaign
    /// @param campaignId The ID of the campaign
    /// @return donors An array of donor addresses
    /// @return contributions An array of contribution amounts corresponding to each donor
    function getCampaignDonors(uint256 campaignId)
        public
        view
        campaignExists(campaignId)
        returns (address[] memory donors, uint256[] memory contributions)
    {
        Campaign storage campaign = campaigns[campaignId];
        uint256 totalDonors = campaign.donorAddresses.length;

        donors = new address[](totalDonors);
        contributions = new uint256[](totalDonors);

        for (uint256 i = 0; i < totalDonors; i++) {
            address donor = campaign.donorAddresses[i];
            donors[i] = donor;
            contributions[i] = campaign.donors[donor];
        }
    }

    /// @notice Allows a user to donate to an active campaign
    /// @param campaignId The ID of the campaign to donate to
    function donate(uint256 campaignId) public payable campaignExists(campaignId) {
        if (msg.value == 0) revert Campaign__EmptyDonation();

        Campaign storage campaign = campaigns[campaignId];
        if (campaign.claimed) revert Campaign__CampaignAlreadyClaimed();
        if (block.timestamp > campaign.deadline) revert Campaign__CampaignClosed();

        if (campaign.donors[msg.sender] == 0) {
            campaign.donorAddresses.push(msg.sender);
        }

        campaign.amountRaised += msg.value;
        campaign.donors[msg.sender] += msg.value;

        emit NewDonation(msg.sender, campaignId, msg.value);

        if(campaign.totalMilestones > 0) {
            Milestone storage currentMilestone = campaign.milestones[campaign.currentMilestone];

            if(campaign.amountRaised >= currentMilestone.targetAmount) {
                currentMilestone.status = MilestoneStatus.Completed;

                if(currentMilestone.id == campaign.totalMilestones - 1) {
                    emit CampaignGoalCompleted(campaign.owner, campaignId, campaign.amountRaised);
                } else {
                    emit MilestoneReached(campaignId, campaign.currentMilestone, campaign.amountRaised);
                    campaign.currentMilestone++;
                    campaign.milestones[campaign.currentMilestone].status = MilestoneStatus.InProgress;
                    emit NextMilestoneStarted(campaignId, campaign.currentMilestone);
                }
            }
        } else {
            if (campaign.amountRaised >= campaign.goal) {
                emit CampaignGoalCompleted(campaign.owner, campaignId, campaign.amountRaised);
            }
        }
    }

    /// @notice Allows a donor to request a refund for their donation
    /// @param campaignId The ID of the campaign to request a refund from
    /// @param amount The amount to refund
    function refund(uint256 campaignId, uint256 amount) public campaignExists(campaignId) {
        Campaign storage campaign = campaigns[campaignId];

        if (campaign.claimed) revert Campaign__CampaignAlreadyClaimed();
        if (block.timestamp >= campaign.refundDeadline) revert Campaign__RefundDeadlineElapsed(campaignId);

        uint256 amountDonated = campaign.donors[msg.sender];
        if (amountDonated == 0) revert Crowdfunding__NoDonationFound(campaignId);

        if (amountDonated < amount) revert Crowdfunding__InsufficientDonation(campaignId, amount, amountDonated);

        campaign.amountRaised -= amount;
        campaign.donors[msg.sender] -= amount;

        if (campaign.donors[msg.sender] == 0) {
            _removeAddress(campaign.donorAddresses, msg.sender);
        }

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert Crowdfunding__RefundFailed(campaignId);

        emit DonationRefunded(msg.sender, campaignId, amount);
    }

    /// @notice Removes an address from an array
    /// @dev Internal function used to remove a donor's address when they have no remaining donation
    /// @param array The array of addresses to modify
    /// @param addressToRemove The address to remove from the array
    /// @return bool Returns true if the address was successfully removed, false otherwise
    function _removeAddress(address[] storage array, address addressToRemove) internal returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == addressToRemove) {
                array[i] = array[array.length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }
}
