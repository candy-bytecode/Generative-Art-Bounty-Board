# Generative Art Bounty Board

A decentralized protocol for posting generative art bounties with verifiable random or community-based winner selection.

## Overview

Generative Art Bounty Board enables creators to post art challenges with rewards. Artists submit generative artwork, and winners are selected through verifiable random selection or manual curation, with all results recorded on-chain.

## Features

- **Bounty Creation**: Post art challenges with themes and rewards
- **Artwork Submission**: Artists submit work with cryptographic hashes
- **Random Selection**: Verifiable on-chain randomness for fair selection
- **Manual Curation**: Creator-driven winner selection option
- **Artist Tracking**: Lifetime win statistics for reputation
- **Deadline Management**: Time-bound submission windows

## Contract Functions

### Public Functions

- `create-bounty`: Post a new art bounty
- `submit-artwork`: Submit artwork for a bounty
- `select-winner-random`: Choose winner via pseudo-random selection
- `select-winner-manual`: Manually select winning submission

### Read-Only Functions

- `get-bounty`: Retrieve bounty details
- `get-submission`: Get submission information
- `get-bounty-submissions`: List all submissions for a bounty
- `get-artist-wins`: View artist's total wins
- `get-bounty-count`: Total bounties created
- `get-submission-count`: Total artworks submitted

## Getting Started
```bash
clarinet contract new generative-art-bounty
clarinet check
clarinet test
```

## Workflow

1. Creator posts bounty with theme, reward, and deadline
2. Artists submit artwork before deadline
3. After deadline, creator selects winner (random or manual)
4. Winner's submission marked on-chain
5. Artist win count incremented

## Randomness

The contract uses block height and nonce-based pseudo-randomness for fair winner selection in random mode.