"use client";

import { Button, ButtonProps } from "@/components/ui/button";
import { toast } from "@/hooks/use-toast";
import { ICampaignDetail } from "@/interfaces/campaign";
import useWalletStore from "@/stores/wallet";

interface WithdrawFundsProps extends Pick<ICampaignDetail, "id"> {
  buttonProps?: ButtonProps;
}

export default function WithdrawFunds({ id, buttonProps }: WithdrawFundsProps) {
  const writeableCrowdChainContract = useWalletStore(
    (state) => state.writeableCrowdChainContract,
  );

  const withdraw = async () => {
    if (!writeableCrowdChainContract) return;

    try {
      const tx = await writeableCrowdChainContract.withdraw(id, {
        gasLimit: 300000,
      });

      await tx.wait();

      toast({
        title: "Funds has been sent to your wallet",
      });
    } catch (error) {
      console.log("__ THERE IS AN ERROR __");
      console.log(error);
    }
  };

  return (
    <Button {...buttonProps} onClick={withdraw}>
      Withdraw
    </Button>
  );
}
