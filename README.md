# PureFi SDK for Solidity (Version 3)

SDK is dedicated for the EVM based networks. Provides KYC and AML verifications for smart contracts based vaults, funds and DeFi protocols. 

SDK provides 3 different verification methods: 
 1. Interactive Mode: requires interaction with Issuer via API before transaction issued. More detail 
 2. Whitelist Mode: completely on-chain mode, but requires pre-publishing of the verified data in whitelist, which is a special smart contract.
 3. Non-Interactive Mode: on-chain verification with the help of ZK-SNARKS. Implementation is still in progress...   

 ## Changelist V2->V3
 1. PureFiVerifier: Interactive mode now supports 3 types of data packages:
    1.1 single address verification (derived from V1 and V2)
    1.2 combined verification of the {from, to, token, amount}, where from - funds sender address, to - funds receiver address, token - token contract address and amount - max amount of tokens sent (max amount means that actual deposit can be less or equal). This type is recommended for a standard deposit functions where single token is sent by user and received by the smart contract.
    1.3 transaction payload verification. This mode is designed for transactions, that combines sending of different tokens at the same time. For example, adding liquidity into the DEX pool. 
2. PureFiVerifier: removed default support for whitelisted credentials. PureFiWhitelist still can be used directly.
2. PureFiContext: upgraded to match PureFiVerifier changes + added helper functions and default rules for V2 compatible implementations. 

*IMPORTANT!* Transaction payload verification is NOT supported by the PureFi Issuer as of today (and thus - can not be used with the Interactive mode currently) and will be enabled with the release of the Transaction Monitoring tool. ETA TBA. 

## Integration example and live demo
Please check the [Live Demo here:](https://frontendsdksolidity.purefi.io/)
Integration documentation is available [here](https://docs.purefi.io/integrate/products/aml-sdk/interactive-mode)

Live Demo is available for both Ethereum and Binance Chain and is built upon the example contracts from this repo:
 * [UFIBuyerBSCWithCheck](./contracts/examples/ex02-filtered_tokenbuyer/UFIBuyerBSCWithCheck.sol)
 * [UFIBuyerETHWithCheck](./contracts/examples/ex02-filtered_tokenbuyer/UFIBuyerETHWithCheck.sol)
## On-chain infrastructure:
### Ethereum mainnet
| Contract name | contract address |
| ----------- | ----------- |
| PureFi Token | 0xcDa4e840411C00a614aD9205CAEC807c7458a0E3 |
| PureFi Verifier (v3) | 0xBa8bFC223Cb1BCDcdd042494FF2C07b167DDC6CA |
| PureFi Subscription | 0xbA5B61DFa9c182E202354F66Cb7f8400484d7071 |
| PureFi Verifier (v2) - Deprecated | 0x714Ca4B117558a043c41f7225b12cB53eF80416e |
### Binance Chain
| Contract name | contract address |
| ----------- | ----------- 
| PureFi Token | 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D |
| PureFi Verifier (V3) | 0x62351A3F17a2c4640f45907faB74901a37FaD3C2 |
| PureFi Subscription | 0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3 |
| PureFi Verifier (V2) - Deprecated| 0x3346cc4b6F44349EAC447b1C8392b2a472a20F27 |

## Documentation
Please check PureFi Wiki site for more details. [AML SDK documentation is here](https://docs.purefi.io/integrate/welcome)
