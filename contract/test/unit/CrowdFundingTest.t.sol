// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Crowdfunding} from "./../../src/Crowdfunding.sol";
import {CrowdchainToken} from "./../../src/tokens/crowdchain.sol";
import {ICampaign} from "./../../src/interfaces/ICampaign.sol";
import {DeployCrowdFunding} from "./../../script/DeployCrowdFunding.s.sol";
import {ConstantsTest} from "./../utils/Constants.sol";

contract CrowdFundingTest is Test, ConstantsTest {
    Crowdfunding public crowdfunding;
    CrowdchainToken public crowdchainToken;
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address BLESSING = makeAddr("blessing");

    function setUp() external {
        vm.deal(DEPLOYER, 100 ether);
        vm.prank(DEPLOYER);
        DeployCrowdFunding deployCampaign = new DeployCrowdFunding();
        (crowdfunding, crowdchainToken) = deployCampaign.run();

        vm.deal(ALICE, 100 ether);
        vm.deal(BOB, 100 ether);
        vm.deal(BLESSING, 100 ether);
    }

    function test_withdrawSuccessfully() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 2;
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, BLESSING_DONATION);
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);

        _shiftCurrentTimestampToAllowWithdraw();

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, BLESSING_DONATION);
        crowdfunding.withdraw(campaignID);
    }

    function test_withdrawMilestonedCampaign() public {
        _createCampignWithMilestones(ALICE);
         uint256 amountNeeded = 40 * 1 ether; // gotten from _createCampignWithMilestones above 

        uint8 firstMilestoneID = 0;
        uint8 secondMilestoneID = 1;
        uint8 thirdMilestoneID = 2;

        uint256 campaignID = 0;

        // ========== first milestone amount -> 7 ether ==========
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 4 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.MilestoneReached(campaignID, firstMilestoneID, 7 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.NextMilestoneStarted(campaignID, secondMilestoneID);
        crowdfunding.donate{value: 4 ether}(campaignID); // total = 7 ethers

        uint256 firstMilestoneTarget = 6 ether;
        uint256 fee = (crowdfunding.OWNER_FEE() * amountNeeded) / 1000;
        uint256 firstAmountWithdrawn = firstMilestoneTarget - fee;
        uint256 aliceFirstBalance = ALICE.balance;

        vm.prank(ALICE);
        // assert withdraw was successful
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, firstAmountWithdrawn);
        crowdfunding.withdraw(campaignID);

        // assert correct amount was withdrawn
        assertEq(ALICE.balance, aliceFirstBalance + firstAmountWithdrawn);

        // ========== second milestone amount -> 16 ether ==========
        uint256 aliceSecondBalance = ALICE.balance;
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 6 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.MilestoneReached(campaignID, secondMilestoneID, 16 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.NextMilestoneStarted(campaignID, thirdMilestoneID);
        crowdfunding.donate{value: 6 ether}(campaignID); // total = 16 ethers
        // ========== second milestone amount -> 16 ether ==========

        uint256 secondMilestoneTarget = 16 ether;
        uint256 secondAmountWithdrawn = secondMilestoneTarget - firstMilestoneTarget;

        vm.prank(ALICE);
        // assert withdraw was successful
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, secondAmountWithdrawn);
        crowdfunding.withdraw(campaignID);

        // assert correct amount was withdrawn
        assertEq(ALICE.balance, aliceSecondBalance + secondAmountWithdrawn);

        // ========== third milestone amount -> 40 ether ==========
        uint256 aliceThirdBalance = ALICE.balance;
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 5 ether);
        crowdfunding.donate{value: 5 ether}(campaignID); // total = 21 ethers

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID); // total = 24 ethers

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 36 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignGoalCompleted(ALICE, campaignID, 60 ether);
        crowdfunding.donate{value: 36 ether}(campaignID); // total = 60 ethers
        // ========== third milestone amount -> 40 ether ==========

        uint256 amountRaised = 60 ether;
        uint256 thirdAmountWithdrawn = amountRaised - (firstAmountWithdrawn + fee + secondAmountWithdrawn);

        vm.prank(ALICE);
        // assert withdraw was successful
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, thirdAmountWithdrawn);
        crowdfunding.withdraw(campaignID);

        // assert correct amount was withdrawn
        assertEq(ALICE.balance, aliceThirdBalance + thirdAmountWithdrawn);
        assertEq(ALICE.balance, aliceFirstBalance + firstAmountWithdrawn + secondAmountWithdrawn + thirdAmountWithdrawn);
    }

    function test_savesAccumalatedFeeCorrectly() public {
        uint256 _amountNeeded = 16 * ONE_ETH;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = 3 * ONE_ETH;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        uint256 totalDonation = DONATION * 2;

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, totalDonation);
        crowdfunding.withdraw(campaignID);

        vm.prank(DEPLOYER);
        uint256 accumulatedFee = crowdfunding.getAccumulatedFee();
        uint256 expectedAccumulatedFee = (crowdfunding.OWNER_FEE() * totalDonation) / 1000;

        assertEq(accumulatedFee, expectedAccumulatedFee);
    }

    function test_allocateCorrectAmountOfTokensAfterOwnerWithdraw() public {
        uint256 _amountNeeded = 16 * ONE_ETH;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = 9 * ONE_ETH;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        uint256 totalDonation = DONATION * 2;

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, totalDonation);
        crowdfunding.withdraw(campaignID);

        vm.prank(DEPLOYER);
        uint256 accumulatedFee = crowdfunding.getAccumulatedFee();
        uint256 expectedAccumulatedFee = (crowdfunding.OWNER_FEE() * totalDonation) / 1000;
        assertEq(accumulatedFee, expectedAccumulatedFee);

        uint256 amountWithdrawn = crowdfunding.getCampaign(0).amountRaised - accumulatedFee;
        uint256 tokenAllocated = (amountWithdrawn / crowdfunding.MINIMUM_AMOUNT_RAISED()) * 10 ** 18;

        assertEq(crowdfunding.getCampaign(0).tokensAllocated, tokenAllocated);
    }

    function test_allocateZeroTokenIfAmountRaisedIsSmall() public {
        uint256 minimumGoalAmount = crowdfunding.MINIMUM_AMOUNT_RAISED();
        uint256 _amountNeeded = minimumGoalAmount - 6 ether;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = _amountNeeded - 4 ether;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, DONATION);
        crowdfunding.withdraw(campaignID);

        assertEq(crowdfunding.getCampaign(campaignID).tokensAllocated, 0);
    }

    // TODO: Write a test for this case
    function test_allowDonorToClaimToken() public {}

    function test_revertClaimTokenWhenUserHasNoDonation() public {
        uint256 _amountNeeded = 16 * ONE_ETH;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = 18 * ONE_ETH;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, DONATION);
        crowdfunding.withdraw(campaignID);

        vm.prank(BOB);
        vm.expectRevert(ICampaign.Campaign__EmptyDonation.selector);
        crowdfunding.claimToken(campaignID);
    }

    function test_revertWhenClaimingTokenFromUnderFundedCampaign() public {
        uint256 minimumGoalAmount = crowdfunding.MINIMUM_AMOUNT_RAISED();
        uint256 _amountNeeded = minimumGoalAmount - 6 ether;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = _amountNeeded - 4 ether;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, DONATION);
        crowdfunding.withdraw(campaignID);

        console.log("___ AMOUNTRAISED ___");
        console.log(crowdfunding.getCampaign(campaignID).amountRaised);

        vm.prank(BLESSING);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICampaign.Campaign__InsufficientDonationsForTokens.selector, 0, DONATION, minimumGoalAmount
            )
        );
        crowdfunding.claimToken(campaignID);
    }

    function test_onlyDeployerCanWithdrawAccumulatedFees() public {
        uint256 _amountNeeded = 16 * ONE_ETH;

        ICampaign.BasicMilestone[] memory _milestones;

        vm.prank(ALICE);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            _amountNeeded,
            4,
            10
        );

        uint256 campaignID = 0;
        uint256 DONATION = 3 * ONE_ETH;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, DONATION);
        crowdfunding.donate{value: DONATION}(campaignID);

        vm.warp(block.timestamp + ((4 + 10) * ONE_DAY));

        uint256 totalDonation = DONATION * 2;

        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, ALICE, totalDonation);
        crowdfunding.withdraw(campaignID);

        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(ICampaign.Campaign__NotContractOwner.selector, BOB));
        crowdfunding.withdrawFee();

        vm.startPrank(DEPLOYER);
        assertNotEq(crowdfunding.getAccumulatedFee(), 0);

        crowdfunding.withdrawFee();
        assertEq(crowdfunding.getAccumulatedFee(), 0);
    }

    function test_donationSuccessful() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        // first donation
        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 2;
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, BLESSING_DONATION);
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);

        ICampaign.CampaignDetails memory campaign = crowdfunding.getCampaign(campaignID);

        assertEq(BLESSING_DONATION, campaign.amountRaised);

        // second donation
        vm.prank(BOB);
        uint256 BOB_DONATION = 1;
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, BOB_DONATION);
        crowdfunding.donate{value: BOB_DONATION}(campaignID);

        campaign = crowdfunding.getCampaign(campaignID);

        assertEq(BOB_DONATION + BLESSING_DONATION, campaign.amountRaised);
    }

    function test_emitAnEventWhenGoalIsMet() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 2;
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, BLESSING_DONATION);
        crowdfunding.donate{value: BLESSING_DONATION * ONE_ETH}(campaignID);

        vm.prank(BOB);
        uint256 BOB_DONATION = 100;
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, BOB_DONATION);

        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignGoalCompleted(ALICE, campaignID, BLESSING_DONATION + BOB_DONATION);

        crowdfunding.donate{value: BOB_DONATION * ONE_ETH}(campaignID);
    }

    function test_startNextMilestoneWhenCurrentIsMet() public {
        _createCampignWithMilestones();

        uint8 firstMilestoneID = 0;
        uint8 secondMilestoneID = 1;
        uint8 thirdMilestoneID = 2;

        uint256 campaignID = 0;

        // ========== first milestone amount -> 7 ether ==========
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 4 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.MilestoneReached(campaignID, firstMilestoneID, 7 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.NextMilestoneStarted(campaignID, secondMilestoneID);
        crowdfunding.donate{value: 4 ether}(campaignID); // total = 7 ethers
        // ========== first milestone amount -> 7 ether ==========

        // ========== second milestone amount -> 16 ether ==========
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID);

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 6 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.MilestoneReached(campaignID, secondMilestoneID, 16 ether);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.NextMilestoneStarted(campaignID, thirdMilestoneID);
        crowdfunding.donate{value: 6 ether}(campaignID); // total = 16 ethers
        // ========== second milestone amount -> 16 ether ==========

        // ========== third milestone amount -> 40 ether ==========
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 5 ether);
        crowdfunding.donate{value: 5 ether}(campaignID); // total = 21 ethers

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, 3 ether);
        crowdfunding.donate{value: 3 ether}(campaignID); // total = 24 ethers

        vm.prank(BOB);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BOB, campaignID, 36 ether); // total = 60 ethers
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignGoalCompleted(ALICE, campaignID, 60 ether);
        crowdfunding.donate{value: 36 ether}(campaignID); // total = 16 ethers
        // ========== third milestone amount -> 40 ether ==========
    }

    function test_getAllDonors() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 2;
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);

        vm.prank(BOB);
        uint256 BOB_DONATION = 1;
        crowdfunding.donate{value: BOB_DONATION}(campaignID);

        (address[] memory donors, uint256[] memory contributions) = crowdfunding.getCampaignDonors(campaignID);

        assertEq(donors[0], BLESSING);
        assertEq(donors[1], BOB);

        assertEq(contributions[0], BLESSING_DONATION);
        assertEq(contributions[1], BOB_DONATION);
    }

    function test_donationFailsIfNoMoneyIsDonated() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 0;
        vm.expectRevert(ICampaign.Campaign__EmptyDonation.selector);
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);
    }

    function test_donationFailsIfCampaignHasBeenClaimed() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 1;
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);

        vm.warp(block.timestamp + 15 * ONE_DAY);

        vm.prank(ALICE);
        crowdfunding.withdraw(campaignID);

        vm.prank(BLESSING);
        vm.expectRevert(ICampaign.Campaign__CampaignAlreadyClaimed.selector);
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);
    }

    function test_donationFailsIfCampaignIsClosed() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.warp(block.timestamp + 15 * ONE_DAY);

        vm.prank(BLESSING);
        uint256 BLESSING_DONATION = 1;
        vm.expectRevert(ICampaign.Campaign__CampaignClosed.selector);
        crowdfunding.donate{value: BLESSING_DONATION}(campaignID);
    }

    function test_donorSuccessfullyGetsRefund() public {
        _createSuccessfulCampaign();

        uint256 campaignID = 0;
        uint256 donation = 5 * ONE_ETH;
        uint256 refundAmount = 3 * ONE_ETH;

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, donation);
        crowdfunding.donate{value: donation}(campaignID);

        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.DonationRefunded(BLESSING, campaignID, refundAmount);
        crowdfunding.refund(campaignID, refundAmount);

        ICampaign.CampaignDetails memory campaign = crowdfunding.getCampaign(campaignID);

        assertEq(campaign.amountRaised, (donation - refundAmount));
    }

    function test_noRefundIfCampaignHasBeenClaimed() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        // donate
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, ONE_ETH);
        crowdfunding.donate{value: ONE_ETH}(campaignID);

        vm.warp(block.timestamp + 15 * ONE_DAY);

        // withdraw
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit ICampaign.CampaignFundWithdrawn(campaignID, BLESSING, ONE_ETH);
        crowdfunding.withdraw(campaignID);

        // refund
        vm.prank(BLESSING);
        vm.expectRevert(ICampaign.Campaign__CampaignAlreadyClaimed.selector);
        crowdfunding.refund(campaignID, ONE_ETH);
    }

    function test_noRefundIfCampaignHasBeenClosed() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        // donate
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, ONE_ETH);
        crowdfunding.donate{value: ONE_ETH}(campaignID);

        vm.warp(block.timestamp + 17 * ONE_DAY);

        // refund
        vm.prank(BLESSING);
        vm.expectRevert(abi.encodeWithSelector(ICampaign.Campaign__RefundDeadlineElapsed.selector, campaignID));
        crowdfunding.refund(campaignID, ONE_ETH);
    }

    function test_noRefundIfDonorHasZeroDonations() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;

        vm.prank(BLESSING);
        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.Crowdfunding__NoDonationFound.selector, campaignID));
        crowdfunding.refund(campaignID, ONE_ETH);
    }

    function test_noRefundIfDonorWantsMoreThanTheyDonated() public {
        _createSuccessfulCampaign();
        uint256 campaignID = 0;
        uint256 donation = 5 * ONE_ETH;
        uint256 refundAmount = donation + ONE_ETH;

        // donate
        vm.prank(BLESSING);
        vm.expectEmit(true, false, false, false, address(crowdfunding));
        emit Crowdfunding.NewDonation(BLESSING, campaignID, donation);
        crowdfunding.donate{value: donation}(campaignID);

        // refund
        vm.prank(BLESSING);
        vm.expectRevert(
            abi.encodeWithSelector(
                Crowdfunding.Crowdfunding__InsufficientDonation.selector, campaignID, refundAmount, donation
            )
        );
        crowdfunding.refund(campaignID, refundAmount);
    }

    function _shiftCurrentTimestampToAllowWithdraw() private {
        uint64 _refundDeadline = 10; // gotten from createSuccessfulCampaign();
        uint64 _deadline = 4; // gotten from createSuccessfulCampaign();
        vm.warp(block.timestamp + ((_refundDeadline + _deadline) * ONE_DAY));
    }

    function _createSuccessfulCampaign() private {
        uint32 _amountNeeded = 6;
        uint64 _deadline = 4; // days
        uint64 _refundDeadline = 10; // days
        string memory _title = "My Title";
        string memory _description = "My little description from my heart, soul and mind";

        _createCampaign(ALICE, _title, _description, _amountNeeded, _deadline, _refundDeadline);
    }

    function _createCampaign(
        address _owner,
        string memory _title,
        string memory _description,
        uint32 _amountNeeded,
        uint64 _deadline,
        uint256 _refundDeadline
    ) private {
        vm.startPrank(_owner);

        ICampaign.BasicMilestone[] memory _milestones;

        // TODO: Use forge to get image metadata
        crowdfunding.createCampaign(
            _title, _description, "coverImage", _milestones, _amountNeeded, _deadline, _refundDeadline
        );

        vm.stopPrank();
    }

    function _createCampignWithMilestones() private {
        _createCampignWithMilestones(ALICE);
    }

    function _createCampignWithMilestones(address owner) private {
        uint256 amountNeeded = 40 * 1 ether;
        uint64 deadline = 15; // days
        uint256 refundDeadline = 10; // days

        ICampaign.BasicMilestone[] memory _milestones = new ICampaign.BasicMilestone[](3);

        _milestones[0] = ICampaign.BasicMilestone({targetAmount: 6 ether, deadline: 2, description: "First milestone"});

        _milestones[1] =
            ICampaign.BasicMilestone({targetAmount: 16 ether, deadline: 4, description: "Second milestone"});

        _milestones[2] =
            ICampaign.BasicMilestone({targetAmount: 40 ether, deadline: 4, description: "Second milestone"});

        vm.prank(owner);
        crowdfunding.createCampaign(
            "My Title",
            "My little description from my heart, soul and mind",
            "coverImage",
            _milestones,
            amountNeeded,
            deadline,
            refundDeadline
        );
    }
}
