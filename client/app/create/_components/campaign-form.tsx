/* eslint-disable @next/next/no-img-element */
"use client";

import { ChangeEvent, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { useForm } from "react-hook-form";
import { DatePicker } from "@/components/ui/date-picker";
import { differenceInDays } from "date-fns";
import { useToast } from "@/hooks/use-toast";
import { uploadImage } from "@/utils/upload-image";
import { useCrowdchainInstance } from "@/hooks/use-crowdchain-instance";
import Milestones from "./milestones";
import { ICampaignForm } from "../_interfaces/form";
import ImportantNotice from "./important-notice";
import { validateMilestoneRules } from "../_utils/milestone-rules";
import { useAccount, useWriteContract } from "wagmi";
import { wagmiAbi } from "@/lib/contracts/crowd-chain/abi";
import { parseEther, parseUnits } from "viem";
import { useCrowdchainAddress } from "@/hooks/use-crowdchain-address";

const oneDay = 1 * 24 * 60 * 60 * 1000;

const CampaignForm = () => {
  const { address: accountAddress } = useAccount();
  const contractAddress = useCrowdchainAddress();
  const { writeContractAsync } = useWriteContract();
  const { crowdchainInstance } = useCrowdchainInstance();
  const { toast } = useToast();
  const [preview, setPreview] = useState<string | null>("second");

  const form = useForm<ICampaignForm>({
    defaultValues: {
      title: "",
      description: "",
      goal: 1,
      deadline: new Date(Date.now() + oneDay),
      refundDeadline: new Date(Date.now() + 6 * oneDay),
      milestones: [],
    },
  });
  const [coverImage, setCoverImage] = useState<File | null>(null);

  function handleChangeImage(e: ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;

    if (!files || files.length === 0) return;

    const file = files[0];

    const preview = URL.createObjectURL(file);

    setCoverImage(file);
    setPreview(preview);
  }

  const {
    formState: { errors },
  } = form;

  const onSubmit = async (data: ICampaignForm) => {
    if (!accountAddress)
      return toast({
        title: "Connect your wallet",
        variant: "destructive",
      });

    if (!coverImage)
      return toast({
        title: "Add your campaign cover image",
        variant: "destructive",
      });

    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const fullNow = new Date(now);

    if (!data.deadline)
      return form.setError("deadline", { message: "Provide deadline" });

    const _deadline = differenceInDays(data.deadline, fullNow);

    if (_deadline < 1)
      return form.setError("deadline", {
        message: "Deadline must be at least a day from now",
      });

    if (!data.refundDeadline)
      return form.setError("refundDeadline", {
        message: "Provide refund deadline",
      });

    const _refundDeadline = differenceInDays(
      data.refundDeadline,
      data.deadline,
    );

    if (_refundDeadline < 5)
      return form.setError("refundDeadline", {
        message: "Refund deadline must be at least 5 days from deadline",
      });

    const milestones = data.milestones;

    if (milestones.length > 0) {
      const rules = Object.values(
        validateMilestoneRules({
          milestones,
          goal: data.goal,
          deadline: data.deadline,
        }),
      );

      if (rules.some((rule) => !rule.valid))
        return toast({
          title: "Fix all milestones error",
          variant: "destructive",
        });
    }

    try {
      console.log("Uploading image....");
      const ifpsImg = await uploadImage(coverImage, crowdchainInstance());

      console.log("Called function...");

      await writeContractAsync({
        abi: wagmiAbi,
        address: contractAddress,
        functionName: "createCampaign",
        args: [
          data.title,
          data.description,
          ifpsImg.IpfsHash,
          milestones.map((milestone) => ({
            targetAmount: parseEther(`${milestone.targetAmount}`),
            deadline: parseUnits(
              String(differenceInDays(milestone.deadline!, fullNow)),
              0,
            ),
            description: milestone.description,
          })),
          parseEther(String(data.goal)),
          parseUnits(String(_deadline), 0),
          parseUnits(String(_refundDeadline), 0),
        ],
      });

      toast({ title: "Your campaign has been created" });
      form.reset();
      setCoverImage(null);
      setPreview(null);
    } catch (error) {
      console.log("__ ERROR ___");
      // TODO: Learn how to handle errors
      console.log(error);
      toast({ title: "There is an error creating your campaign" });
    }
  };

  const deadline = form.watch("deadline");

  return (
    <div className="container mx-auto px-4 py-8">
      <form
        onSubmit={form.handleSubmit(onSubmit)}
        className="max-w-2xl mx-auto"
      >
        <Card className="">
          <CardHeader>
            <CardTitle className="text-2xl font-bold text-left">
              Create New Campaign
            </CardTitle>
            <CardDescription>
              <ImportantNotice className="mt-[-0.7rem]" />
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col space-y-6">
            <div className="space-y-2">
              <Label htmlFor="title">Campaign Title</Label>
              <Input
                id="title"
                {...form.register("title", {
                  required: "Title is required",
                  minLength: 1,
                  maxLength: 200,
                })}
                placeholder="Enter campaign title"
              />
              {errors.title && (
                <p className="text-red-500 text-sm">{errors.title.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                {...form.register("description", {
                  required: "Description is required",
                  minLength: 10,
                })}
                placeholder="Describe your campaign"
                rows={4}
              />
              {errors.description && (
                <p className="text-red-500 text-sm">
                  {errors.description.message}
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="goal">Funding Goal (in ETH)</Label>
              <Input
                id="goal"
                type="number"
                {...form.register("goal", {
                  required: "Funding goal is required",
                  // min: { value: 0, message: "Goal must be positive" },
                  validate: (value) =>
                    value > 0 || "Goal must be greater than 0",
                })}
                placeholder="Enter funding goal"
                step="0.00000000001"
              />
              {errors.goal && (
                <p className="text-red-500 text-sm">{errors.goal.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="deadline">Campaign Deadline</Label>
              <div>
                <DatePicker
                  triggerProps={{ className: "w-full" }}
                  calendar={{
                    selected: deadline,
                    mode: "single",
                    fromDate: new Date(Date.now() + oneDay),
                    onSelect: (date) => {
                      form.setValue("deadline", date);

                      if (!date) {
                        return form.setError("deadline", {
                          message: "Select a date",
                        });
                      }

                      form.clearErrors("deadline");
                    },
                  }}
                />
              </div>
              {errors.deadline && (
                <p className="text-red-500 text-sm">
                  {errors.deadline.message}
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="refundDeadline">Refund Deadline</Label>
              <div>
                <DatePicker
                  triggerProps={{ className: "w-full", disabled: !deadline }}
                  calendar={{
                    selected: form.watch("refundDeadline"),
                    mode: "single",
                    disabled: !deadline,
                    fromDate: deadline
                      ? new Date(new Date(deadline).getTime() + 6 * oneDay)
                      : undefined,
                    onSelect: (date) => {
                      form.setValue("refundDeadline", date);

                      if (!date)
                        return form.setError("refundDeadline", {
                          message: "Select a deadline date",
                        });

                      form.clearErrors("refundDeadline");
                    },
                  }}
                />
              </div>
              {errors.refundDeadline && (
                <p className="text-red-500 text-sm">
                  {errors.refundDeadline.message}
                </p>
              )}
            </div>

            {/* TODO: Upload image instead */}
            <div className="space-y-2">
              <Label htmlFor="coverImage">Cover Image</Label>
              <Input
                id="coverImage"
                name="coverImage"
                onChange={handleChangeImage}
                placeholder="Provide a campaign image"
                type="file"
                accept="image/*"
                multiple={false}
              />
              {!coverImage && (
                <p className="text-red-500 text-sm">Cover Image is required</p>
              )}
              {preview && (
                <figure className="flex items-center justify-center rounded-lg max-h-[25rem] overflow-hidden">
                  <img src={preview} alt="" />
                </figure>
              )}
            </div>
          </CardContent>
        </Card>

        <Milestones form={form} />
        <ImportantNotice className="mt-2" />

        <Button
          type="submit"
          className="w-full mt-8 max-w-80 mx-auto block"
          disabled={form.formState.isSubmitting}
        >
          Create Campaign
        </Button>
      </form>
    </div>
  );
};

export default CampaignForm;
