# 🃏 Onchain Casino (Portfolio Project)

This is a modular and upgradeable on-chain casino built to showcase advanced Solidity architecture, including:

- 🧠 **Account Abstraction (ERC-4337)** for seamless UX (users play without signing every transaction)
- 🛠️ **Upgradeable contracts** via Proxy pattern for future extensibility
- 🎲 **Chainlink VRF** for provably fair randomness
- 🎮 Multiple games: starting with **Blackjack**, more to come (Roulette, Slots, sports bets...)

## 🔧 Architecture Overview

- `CasinoBank`: accepts user deposits and mints `CasinoToken`
- `CasinoToken`: ERC-20 token used inside the casino for gameplay
- `Relayer`: backend component that submits user actions to the blockchain via Account Abstraction
- `SmartWallets`: created for users via AA, allowing the casino to act on their behalf 
- `Game contracts`: isolated logic per game (e.g. Blackjack, Slots), fully verifiable on-chain
- `Chainlink VRF`: integrated for randomness in games (card draws, spins, etc.)

## 💡 Tech Stack

- Solidity + Foundry
- ERC-4337 (AA)
- OpenZeppelin Upgradeable Contracts
- Chainlink VRF (Testnet)
---

This is not a real-money gambling product. This project is for educational and portfolio purposes only.
