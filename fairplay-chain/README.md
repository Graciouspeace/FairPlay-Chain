ClarityBet: Decentralized Gambling Platform
ClarityBet is a fair and transparent casino built on the Stacks blockchain using the Clarity smart contract language. The platform offers several classic gambling games with provably fair outcomes ensured by blockchain technology.
Features

Fully Decentralized: All games run entirely on-chain with transparent code and execution.
Provably Fair: Uses blockchain VRF (Verifiable Random Function) seeds for generating random numbers.
Low House Edge: Competitive 5% house fee, configurable by the contract owner.
Multiple Games:

Coin Flip (50/50 chance)
Dice Roll (variable risk/reward)
Roulette (multiple betting options)


Transparent Payouts: All game results and payouts are publicly verifiable on the blockchain.

Games Offered
Coin Flip
A simple 50/50 game where players bet on either Heads (0) or Tails (1). Winning pays 2x your bet minus the house fee.
Dice Roll
Players choose a target number (1-5) and win if the dice roll (1-6) exceeds their target number. The lower the target, the higher the potential payout, but the lower the probability of winning.
Roulette
A simplified version of the classic casino game with a standard 0-36 wheel. Betting options include:

Single number (pays 35:1)
Red/Black (pays 1:1)
Even/Odd (pays 1:1)
High/Low (pays 1:1)

Getting Started
Prerequisites

A Stacks wallet (like Hiro Wallet or Xverse)
STX tokens for betting

How to Play

Connect your Stacks wallet to the ClarityBet interface
Choose a game to play
Set your bet amount (between 1-1000 STX)
Place your bet
Results are determined immediately and payouts are processed automatically

Technical Details
Smart Contract Functions
Game Functions

play-coinflip: Place a bet on a coin flip game
play-diceroll: Place a bet on a dice roll game
play-roulette: Place a bet on various roulette options

Administrative Functions

withdraw-house-fees: Allows the contract owner to withdraw collected fees
update-house-fee: Updates the house fee percentage (owner only)
update-bet-limits: Updates the minimum and maximum bet limits (owner only)
set-contract-paused: Emergency pause function (owner only)
emergency-refund: Refund a specific game in case of errors (owner only)

Read-Only Functions

get-platform-stats: Returns platform statistics
get-player-games: Returns games played by a specific player
get-game: Returns details about a specific game
is-contract-paused: Checks if the contract is currently paused

Randomness Generation
The contract uses a combination of blockchain VRF seeds and game-specific parameters to generate random numbers for game outcomes. This ensures that results cannot be manipulated or predicted.
Security

House fees are securely stored in the contract and can only be withdrawn by the contract owner
Minimum and maximum bet limits protect both players and the platform
Emergency pause function allows for halting operations if needed
All game results are determined on-chain with no off-chain dependencies

Future Development

Additional games (Blackjack, Slots, Poker)
Player rewards and loyalty program
Integration with NFTs for exclusive games
Multi-player games with pooled betting