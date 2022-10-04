import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { Contract } from "ethers";
import { Distributor, PureFiSubscriptionService, PureFiTokenBuyerETH, TestToken } from "../typechain-types";
import { BigNumber } from "ethers";
import { PromiseOrValue } from "../typechain-types/common";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { parseEther } from "ethers/lib/utils";
import { increase } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time";

const WethAddress: string = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const UFIAddressETH = "0xcDa4e840411C00a614aD9205CAEC807c7458a0E3";
const Hour = 3600;
const Day = 24 * Hour;
const Month = 30 * Day;
const Year = 12 * Month;
const decimals = BigNumber.from(10).pow(BigNumber.from(18));
// for debugging
let counter: number = 1;
describe("Subscription Service", function () {

    let admin;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carl: SignerWithAddress;
    let subscriptionContract: PureFiSubscriptionService;
    let burnAddress: SignerWithAddress;
    let tokenBuyer: PureFiTokenBuyerETH;
    let realUFIAddress = UFIAddressETH;
    let pureFiToken: TestToken;
    let distributeContract: Distributor;
    let lastDistributionTimestamp: number;






    before(async () => {
        [admin, alice, bob, carl, burnAddress] = await ethers.getSigners();
        alice.address;
        const SubService = await hre.ethers.getContractFactory("PureFiSubscriptionService");
        const TokenBuyer = await hre.ethers.getContractFactory("PureFiTokenBuyerETH");
        const TestToken = await hre.ethers.getContractFactory("TestToken");
        const WETH = await hre.ethers.getContractAt("IWETH", WethAddress);
        const Distributor = await hre.ethers.getContractFactory("Distributor");


        tokenBuyer = await TokenBuyer.deploy();
        await tokenBuyer.initialize();

        pureFiToken = TestToken.attach(UFIAddressETH);
        subscriptionContract = await SubService.deploy();

        await subscriptionContract.initialize(admin.address, pureFiToken.address, tokenBuyer.address, burnAddress.address);

        distributeContract = await Distributor.deploy();

    });

    it("set tiers", async function () {

        await subscriptionContract.setTierData(
            BigNumber.from("1"),
            BigNumber.from(Year),
            BigNumber.from("50"),
            BigNumber.from("20"),
            BigNumber.from("1"),
            BigNumber.from("5")
        );

        await subscriptionContract.setTierData(
            BigNumber.from("2"),
            BigNumber.from(Year),
            BigNumber.from("100"),
            BigNumber.from("20"),
            BigNumber.from("1"),
            BigNumber.from("15")
        );

        await subscriptionContract.setTierData(
            BigNumber.from("3"),
            BigNumber.from(Year),
            BigNumber.from("300"),
            BigNumber.from("20"),
            BigNumber.from("1"),
            BigNumber.from("45")
        );

        console.log(await subscriptionContract.getTierData(BigNumber.from("1")));
        console.log(await subscriptionContract.getTierData(BigNumber.from("2")));
        console.log(await subscriptionContract.getTierData(BigNumber.from("3")));
    });

    it("set profit distribution params", async function () {
        await subscriptionContract
            .setProfitDistributionParams(
                distributeContract.address,
                BigNumber.from(20),
                BigNumber.from(Month)
            );
    });

    it("buy subscription", async function () {

        // subscribe alice

        console.log("User stat before first subscription : \n", await subscriptionContract.getUserStat());

        await subscriptionContract
            .connect(alice)
            .subscribe(
                BigNumber.from(1),
                {
                    value: parseEther('0.5')
                }
            );
        console.log("Service balance after 1st subscription: ", await pureFiToken.balanceOf(subscriptionContract.address));

        console.log("User stat after first subscription : \n", await subscriptionContract.getUserStat());


        console.log("Distributor allowance before first distribution : ", await pureFiToken.allowance(subscriptionContract.address, distributeContract.address));
        console.log("BurnAddr balance before 1st distribution : ", await pureFiToken.balanceOf(burnAddress.address))
        // distribute profit after 5 hour with only 1 active subscription
        let firstProfit;
        let estimatedProfit1;
        {
            // increase block for 5 hour

            let tx_timestamp = await time.increase(15 * Day);
            
            estimatedProfit1 = await subscriptionContract.estimateProfit();

            let tx = await subscriptionContract.distributeProfit();

            let subscriptionDate = (await subscriptionContract.getUserData(alice.address))[1];
            let depositedAmount = (await subscriptionContract.getUserData(alice.address))[4];
            let burnRate = (await subscriptionContract.getTierData(BigNumber.from(1)))[2];

            let estimation =
                (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year);
            console.log("Estimation : ", estimation);
            firstProfit = estimation;
           
        }

        isSimilar(estimatedProfit1, firstProfit, 100000n);

        console.log("Distributor balance after first distribution : ", await pureFiToken.allowance(subscriptionContract.address, distributeContract.address));
        console.log("BurnAddr balance after 1st distribution : ", await pureFiToken.balanceOf(burnAddress.address))

        // subscribe bob
        await time.increase(15 * Day);

        console.log("User data before 2nd subscription : ", await subscriptionContract.getUserStat());
        await subscriptionContract
            .connect(bob)
            .subscribe(
                BigNumber.from(2),
                {
                    value: parseEther('1')
                }
            );
        
        console.log("Service balance : ", await pureFiToken.balanceOf(subscriptionContract.address));
        console.log("Distributor balance before 2nd distribution : ", await pureFiToken.allowance(subscriptionContract.address, distributeContract.address));
        console.log("BurnAddr balance before 2st distribution : ", await pureFiToken.balanceOf(burnAddress.address))

        let secondProfit;
        let estimatedProfit2;
        {
            let tx_timestamp = await time.increase(15 * Day);

            estimatedProfit2 = await subscriptionContract.estimateProfit();

            await subscriptionContract.distributeProfit();

            // count for alice
            let aliceEstimation;
            {
                let aliceData = await subscriptionContract.getUserData(alice.address);
                let subscriptionDate = aliceData[1];
                let depositedAmount = aliceData[4];
                let burnRate = (await subscriptionContract.getTierData(BigNumber.from(1)))[2];

                let estimation = (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year)
                    .sub(firstProfit); // substract first profit
                aliceEstimation = estimation;
            }
            // count bob
            let bobEstimation;
            {
                let bobData = await subscriptionContract.getUserData(bob.address);
                let subscriptionDate = bobData[1];
                let depositedAmount = bobData[4];
                let burnRate = (await subscriptionContract.getTierData(BigNumber.from(2)))[2];

                let estimation = (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year);
                bobEstimation = estimation;
            }
            secondProfit = aliceEstimation.add(bobEstimation);
            // console.log("Second estimation : ", secondProfit);

        }

        isSimilar(secondProfit, estimatedProfit2, 100000n);

        console.log("Distributor balance after 2nd distribution : ", await pureFiToken.allowance(subscriptionContract.address, distributeContract.address));
        console.log("BurnAddr balance after 2st distribution : ", await pureFiToken.balanceOf(burnAddress.address))

        //subscribe carl
        await time.increase(15 * Day);

        await subscriptionContract
            .connect(carl)
            .subscribe(
                BigNumber.from(3),
                {
                    value: parseEther('1')
                }
            );
        console.log(await subscriptionContract.getUserData(carl.address));


        // distribute profit after with 3 active subscriptions
        let thirdProfit;
        let estimatedProfit3;
        {
            let timestamp = await time.increase(15 * Day);
            lastDistributionTimestamp = timestamp;
            
            estimatedProfit3 = await subscriptionContract.estimateProfit();

            await subscriptionContract.distributeProfit();

            // alice part
            let aliceEstimation;
            {
                let tx_timestamp = timestamp;
                let aliceData = await subscriptionContract.getUserData(alice.address);
                let subscriptionDate = aliceData[1];
                let depositedAmount = aliceData[4];
                let burnRate = (await subscriptionContract.getTierData(BigNumber.from(1)))[2];

                let estimation = (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year);
                aliceEstimation = estimation;
            }
            //bob part
            let bobEstimation;
            {
                let tx_timestamp = timestamp;
                let bobData = await subscriptionContract.getUserData(bob.address);
                let subscriptionDate = bobData[1];
                let depositedAmount = bobData[4];
                let burnRate = (await subscriptionContract.getTierData(BigNumber.from(2)))[2];

                let estimation = (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year);
                bobEstimation = estimation;
            }
            //carl part
            let carlEstimation;
            {
                let tx_timestamp = timestamp;
                let carlData = await subscriptionContract.getUserData(carl.address);
                let subscriptionDate = carlData[1];
                let depositedAmount = carlData[4];
                let burnRate = (await subscriptionContract.getTierData(BigNumber.from(2)))[2];

                let estimation = (BigNumber.from(tx_timestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(Year);
                carlEstimation = estimation;
            }
            thirdProfit = aliceEstimation
                .add(bobEstimation)
                .add(carlEstimation)
                .sub(firstProfit)
                .sub(secondProfit);

        }

        // console.log("Third profit : ", thirdProfit)
        isSimilar(estimatedProfit3, thirdProfit, 100000n);

    });



    it("Check unrealized profit", async function () {

        // estimation of unrealized profit
        //      Collected       Unrealized
        //     _____________ ___________________
        //     |            |                  |
        // ----X------------o------------------X--------------O-------------
        // subDate      lastProfitDate      unsubDate       expirationDate
        //     |                               |
        //     ---------------------------------
        //              Total


        // alice unsubscribe

        await time.increase(10 * Day);

        let current_timestamp = await time.latest();
        let estimatedUnrealized;
        {
            let aliceData = await subscriptionContract.getUserData(alice.address);
            let subscriptionDate = aliceData[1];
            let depositedAmount = aliceData[4];
            let burnRate = (await subscriptionContract.getTierData(BigNumber.from(1)))[2];

            let subscriptionDuration = BigNumber.from(current_timestamp).sub(subscriptionDate);
            subscriptionDuration = (
                BigNumber.from(1)
                    .add(
                        subscriptionDuration
                            .div(BigNumber.from(Month))
                    )
                    .mul(BigNumber.from(Month))
            );

            let lastProfit =
                (BigNumber.from(lastDistributionTimestamp).sub(subscriptionDate))
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(BigNumber.from(Year));

            // console.log("lastProfit : ", lastProfit);

            let total =
                subscriptionDuration
                    .mul(depositedAmount)
                    .mul(burnRate)
                    .div(BigNumber.from(100))
                    .div(BigNumber.from(Year));

            // console.log("total : ", total);

            estimatedUnrealized = total.sub(lastProfit);

            console.log("unrealizedProfit(test) : ", estimatedUnrealized);

        }
        // unsubscribe alice for checking unrealized profit
        await subscriptionContract.connect(alice).unsubscribe({ from: alice.address });

        let unrealized = (await subscriptionContract.getProfitCalculationDetails())[1];

        // check that difference between result is less than 0.001%
        isSimilar(unrealized, estimatedUnrealized, 100000n);


    });



})

function isSimilar(a: any, b: any, delta: any) {
    expect(a.sub(b).abs()).to.be.lt(a.div(delta), "Fail comparison");

}
