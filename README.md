# Shapes Game - Starknet

A daily shapes-based puzzle game built on Starknet using Cairo 1.0. Players solve geometric puzzles by finding valid combinations of shapes that match the daily challenge.

## Overview

The Shapes Game is a smart contract-based puzzle where:
- Each day presents a new set of compound shapes
- Players must find valid combinations of basic shapes that match the target
- Scores are recorded on-chain
- Players can only attempt each daily puzzle once

## Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/)
- [Cairo 1.0](https://cairo-lang.org/)

## Installation

1. Clone the repository

```bash
git clone https://github.com/ismaeldm95/shapes-contracts.git
cd shapes-contracts
```

2. Install dependencies

```bash
scarb install
```


## Building

Build the project using Scarb:

```bash
scarb build
```

## Testing

Run the test suite using Starknet Foundry:

```bash
snforge test
```

## Game Rules

1. Each day presents a new set of compound shapes
2. Players get multiple attempts to solve each shape
3. Each solution must use unique basic shapes
4. Solutions are scored based on efficiency and correctness
5. Players can only submit one solution per day

