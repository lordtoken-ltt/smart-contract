# LordToken Contracts

This repo contains all the contracts used in LordToken.

| Smart Contract Name                                                   | Description                                                                                   |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------|
| [LTT](./contracts/LTT.sol)                                            | BEP20 LTT smart contract. Not to be used for new contracts.                                   |
| [Migration](./contracts/Migrations.sol)                               | Truffle Migration smart contract                                                              |
| [Vesting1](./contracts/Vesting1.sol)                                  | Manage first round ICO investisors                                                            |
| [Vesting2](./contracts/Vesting1.sol)                                  | Manage second round ICO investisors                                                           |
| [Vesting3](./contracts/Vesting1.sol)                                  | Manage last round ICO investisors                                                             |

These contracts **should not be used for new contracts**. Please use [OpenZeppelin contracts and libraries](https://github.com/OpenZeppelin/openzeppelin-contracts) for compatibility with new Solidity versions.
