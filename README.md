# PureFi SDK for Solidity

SDK is dedicated for the EVM based networks. Provides KYC and AML verifications for smart contracts based vaults, funds and DeFi protocols. 

SDK provides 3 different verification methods: 
 1. Interactive Mode: requires interaction with Issuer via API before transaction issued. More detail 
 2. Whitelist Mode: completely on-chain mode, but requires pre-publishing of the verified data in whitelist, which is a special smart contract.
 3. Non-Interactive Mode: on-chain verification with the help of ZK-SNARKS. Implementation is still in progress...   

## Integration example and live demo
Please check the [Live Demo here:](https://frontendsdksolidity.purefi.io/)
Integration documentation is available [here](https://docs.purefi.io/integrate/products/aml-sdk/interactive-mode)

Live Demo is available for both Ethereum and Binance Chain and is built upon the example contracts from this repo:
 * [UFIBuyerBSCWithCheck](./contracts/examples/ex02-filtered_tokenbuyer/UFIBuyerBSCWithCheck.sol)
 * [UFIBuyerETHWithCheck](./contracts/examples/ex02-filtered_tokenbuyer/UFIBuyerETHWithCheck.sol)
## On-chain infrastructure:
### Ethereum mainnet
| PureFi Token | 0xcDa4e840411C00a614aD9205CAEC807c7458a0E3 |
| PureFi Verifier | 0x714Ca4B117558a043c41f7225b12cB53eF80416e |
| PureFi Subscription | 0xbA5B61DFa9c182E202354F66Cb7f8400484d7071 |
### Binance Chain
| PureFi Token | 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D |
| PureFi Verifier | 0x3346cc4b6F44349EAC447b1C8392b2a472a20F27 |
| PureFi Subscription | 0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3 |

## Documentation
Please check PureFi Wiki site for more details. [AML SDK documentation is here](https://docs.purefi.io/integrate/welcome)
