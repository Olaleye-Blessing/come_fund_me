// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ICampaign
/// @author Olaleye Blessing
/// @notice Interface for the core functionality of a crowdfunding campaign system
interface ICampaign {
    enum MilestoneStatus {
        Pending, // Milestone is yet to be started
        InProgress, // Milestone is currently being worked on
        Completed, // Milestone has been completed
        Approved, // Milestone has been approved by the campaign owner or stakeholders
        Rejected // Milestone was rejected

    }

    /// @dev Struct containing details of a milestone
    struct Milestone {
        uint8 id;
        uint256 targetAmount;
        uint256 deadline;
        string description;
        MilestoneStatus status;
    }

    struct BasicMilestone {
        uint256 targetAmount;
        uint256 deadline;
        string description;
    }

    /// @notice Struct containing details of a campaign
    struct CampaignDetails {
        uint256 id;
        uint256 amountRaised;
        uint256 deadline;
        uint256 refundDeadline;
        uint256 goal;
        address owner;
        string title;
        string description;
        string coverImage;
        bool claimed;
        uint256 totalDonors;
        uint256 tokensAllocated;
    }

    /// @notice Emitted when a campaign reached a milestone
    /// @dev The next milestone, if available, is started immediately the current one ends
    /// @param campaignId The id of the campaign
    /// @param milestoneId The id of the completed milestone
    /// @param amountRaised The amount raised for the milestone
    event MilestoneReached(uint256 indexed campaignId, uint8 milestoneId, uint256 amountRaised);

    /// @notice Emitted when a new campaign's milestone just started.
    /// @param campaignId The id of the campaign
    /// @param milestoneId The id of the completed milestone
    event NextMilestoneStarted(uint256 indexed campaignId, uint8 milestoneId);

    /// @notice Emitted when campaign funds are withdrawn by the owner
    /// @param campaignId The ID of the campaign
    /// @param owner The address of the campaign owner
    /// @param amount The amount withdrawn
    event CampaignFundWithdrawn(uint256 indexed campaignId, address indexed owner, uint256 amount);

    /// @notice Emitted when a campaign reaches its funding goal
    /// @param owner The address of the campaign owner
    /// @param campaignId The ID of the campaign
    /// @param amountRaised The total amount raised by the campaign
    event CampaignGoalCompleted(address indexed owner, uint256 indexed campaignId, uint256 amountRaised);

    error Campaign__MilestoneGoalNotCompeleted(uint256 campaignId, uint8 milestoneId, uint256 amountRaised);

    /// @notice Error thrown when the account performing an operation is not the contract's owner
    error Campaign__NotContractOwner(address account);

    /// @notice Error thrown when a campaign does not exist
    error Campaign__CampaignNotExist(uint256 campaignId);

    /// @notice Error thrown when campaign creation fails
    error Campaign__CampaignCreationFailed(string reason);

    /// @notice Error thrown when attempting to make an empty donation
    error Campaign__EmptyDonation();

    /// @notice Error thrown when attempting to interact with a closed campaign
    error Campaign__CampaignClosed();

    /// @notice Error thrown when attempting to interact with an already claimed campaign
    error Campaign__CampaignAlreadyClaimed();

    /// @notice Error thrown when a non-owner attempts to perform an owner-only action
    error Campaign__NotCampaignOwner();

    /// @notice Error thrown when a withdrawal fails
    error Campaign__WithdrawalFailed();

    /// @notice Error thrown when invalid pagination parameters are provided
    error Campaign__InvalidPagination();

    /// @notice Error thrown when attempting to interact with a campaign that hasn't ended
    error Campaign__CampaignNotEnded();

    /// @notice Error thrown when attempting to interact with a campaign that has insufficient donation to get tokens
    error Campaign__InsufficientDonationsForTokens(uint256 campaignId, uint256 amountRaised, uint256 minimumDonation);

    /// @notice Error thrown when token distribution fails
    error Campaign__TokenDistributionFailed();

    /// @notice Error thrown when an address interacting with a campaign has claimed their tokens
    error Campaign__TokensClaimed();

    /// @notice Error thrown when attempting to withdraw funds while the refund deadline is still active
    error Campaign__RefundDeadlineActive();

    /// @notice Error thrown when attempting to refund after the refund deadline has elapsed
    error Campaign__RefundDeadlineElapsed(uint256 campaignId);

    /// @dev Returns the address of the contract owner.
    function getOwner() external returns (address owner);

    /// @notice Creates a new campaign
    /// @param title The title of the campaign
    /// @param description The description of the campaign
    /// @param coverImage The URL of the campaign's cover image
    /// @param goal The funding goal of the campaign (in wei)
    /// @param duration The duration of the campaign in days
    /// @param refundDeadline The number of days after the campaign ends during which refunds are possible
    function createCampaign(
        string memory title,
        string memory description,
        string memory coverImage,
        BasicMilestone[] memory milestones,
        uint256 goal,
        uint64 duration,
        uint256 refundDeadline
    ) external;

    /// @notice Retrieves the details of a specific campaign. Make sure the campaign exists
    /// @param campaignId The ID of the campaign to retrieve
    /// @return The CampaignDetails struct containing the campaign's information
    function getCampaign(uint256 campaignId) external view returns (CampaignDetails memory);

    /// @notice Retrieves the milestones of a campaign if it has any
    /// @param campaignId The ID of the campaign milestones to retrieve
    /// @return milestones An array of milestones for the specified campaign
    /// @return currentMileStone The ID of the current milestone or 0 if no milestones are defined
    function getCampaignMileStones(uint256 campaignId)
        external
        view
        returns (Milestone[] memory milestones, uint8 currentMileStone);

    /// @notice Retrieves a paginated list of all campaigns
    /// @param page The page number to retrieve
    /// @param perPage The number of campaigns per page
    /// @return An array of CampaignDetails structs and the total number of campaigns
    function getCampaigns(uint256 page, uint256 perPage) external view returns (CampaignDetails[] memory, uint256);

    /// @notice Retrieves a paginated list of campaigns for a specific owner
    /// @param owner The address of the campaign owner
    /// @param page The page number to retrieve
    /// @param perPage The number of campaigns per page
    /// @return An array of CampaignDetails structs and the total number of campaigns for the owner
    function getOwnerCampaigns(address owner, uint256 page, uint256 perPage)
        external
        view
        returns (CampaignDetails[] memory, uint256);

    /// @notice Allows the campaign owner to withdraw funds after the campaign and refund period have ended
    /// @param campaignId The ID of the campaign to withdraw funds from
    function withdraw(uint256 campaignId) external;

    /// @dev Allows contract owner to withdraw accumulated fee
    function withdrawFee() external;

    /// @dev Retrieves contract accumulated fee
    function getAccumulatedFee() external returns (uint256);

    /// @notice Allows donor to claim their token from a campaign
    function claimToken(uint256 campaignId) external;
}
