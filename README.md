# Asymmetric Public-Goods Experiment Replication

This repository contains an ongoing replication and extension of an asymmetric public-goods experiment using R.

## Project Goal
This project reconstructs a repeated four-player public-goods experiment and examines how different inequality structures affect group contribution, surplus, and payoff inequality.

## Current Progress
- Imported and validated a 12,480-observation player-round dataset.
- Checked missingness, duplicate observation keys, round completeness, group size, player roster, and contribution bounds.
- Constructed player-level variables including endowment, productivity, relative contribution, effective contribution, reward, and monetary payoff.
- Constructed group-round and group-session measures, including group relative contribution, surplus, and payoff inequality.
- Partially replicated key Figure 4 treatment-level patterns for average contribution, surplus, and payoff inequality.

## Repository Structure
- `R/01_import.R`: imports raw data and performs raw-data integrity checks.
- `R/02_derive_variables.R`: constructs player-level and group-level analysis variables.
- `R/03_replication.R`: produces treatment summaries, method-sensitivity checks, and replication figures.
- `figures/`: stores replication figures.
- `data/`: contains data notes.

## Figures
- `figure_4a_replication.png`: average group relative contribution by treatment.
- `figure_4c_replication.png`: overall surplus by treatment.
- `figure_4d_replication.png`: payoff inequality by treatment.

## Ongoing Extension
The next step is to extend the project toward role-specific behavioral heterogeneity and a simplified agent-based computational extension of the experimental setting.

## Software
The project is implemented in R. Main packages include `ggplot2`.