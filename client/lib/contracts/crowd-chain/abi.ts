export const crowdChainABI = [
  "function createCampaign(string title, string description, string coverImage, uint256 goal, uint64 duration, uint256 refundDeadline)",
  "function getCampaign(uint256 campaignId) view returns (tuple(uint256 id, uint256 amountRaised, uint256 deadline, uint256 refundDeadline, uint256 goal, address owner, string title, string description, string coverImage, bool claimed, uint256 totalDonors))",
];
