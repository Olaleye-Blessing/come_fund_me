import { ICampaignDetail } from "@/interfaces/campaign";
import { formatEther } from "ethers/lib/utils";

export const constructCampaign = (_campaign: any): ICampaignDetail => {
  return {
    id: _campaign.id.toString(),
    amountRaised: +formatEther(_campaign.amountRaised),
    deadline: _campaign.deadline.toNumber(),
    refundDeadline: _campaign.refundDeadline.toNumber(),
    goal: +formatEther(_campaign.goal),
    owner: _campaign.owner,
    title: _campaign.title,
    description: _campaign.description,
    coverImage: `https://aquamarine-definite-canidae-414.mypinata.cloud/ipfs/${_campaign.coverImage || "QmZK7UDVm4EpSzvwWjGDvBfvrCduyPW5vHWwtC9u5wjULS"}`,
    claimed: _campaign.claimed,
    totalDonors: +_campaign.totalDonors.toString(),
  };
};
