# Four-player extension specification

Written before simulation results, 2026-09-07.

## Research question and scope

Do the paper's dyadic reciprocity and contribution-fairness mechanisms, with its reported two-player fitted preference parameters transferred unchanged, describe cooperation and surplus in its four-player experiments?

This is a new computational extension, not a reproduction of a published four-player learning model. It is a descriptive transfer check, not a causal estimate or a new calibration. The author-uploaded PDF mentioned in the task is unavailable locally; the public author-hosted final article (DOI 10.1073/pnas.2525760123) and its public supplement are the references used here.

## Verified original settings

Sources: `reference/paper.pdf` (Methods, Eq. 4); `reference/supplement.pdf` pp. 13-16, Table S15; author MATLAB files downloaded from Zenodo 16918146 (CC BY 4.0). Parameters below are direct Table S15 transcriptions, visually checked.

| Game | Treatment | Endowments, agents 1-4 | Productivities, agents 1-4 | Threshold | Reward per player |
|---|---|---|---|---|---|
| linear | FE | 24,24,24,24 | 3.2,3.2,3.2,3.2 | n/a | sum(p*c)/4 |
| linear | AI | 36,36,12,12 | 3.8,3.8,2.6,2.6 | n/a | sum(p*c)/4 |
| linear | MI | 36,36,12,12 | 2.6,2.6,3.8,3.8 | n/a | sum(p*c)/4 |
| threshold | FE | 24,24,24,24 | 1,1,1,1 | 48 | 20 if successful, else 0 |
| threshold | AI | 36,36,12,12 | 3,3,1,1 | 120 | 20 if successful, else 0 |
| threshold | MI | 36,36,12,12 | 1,1,3,3 | 72 | 20 if successful, else 0 |

Contributions are integers from 0 through each player's endowment. Payoff is e_i-c_i+reward. Rewards are renewed each round; payoffs do not accumulate into next-round endowments. Success includes equality at the threshold.

Original dyadic strategy: an initial action plus an integer action for each possible previous coplayer action. Original introspection: uniform random alternative entire strategy, one random revising agent, a full counterfactual 20-round episode, logistic acceptance using the difference in average utility. Initial actions restart each episode. Others keep their strategies but respond anew to counterfactual history.

Reported optimal (s,beta,gamma), SI p.13: linear (1,0,14), threshold (1,18,94). These differ from the illustrative defaults in the distributed MATLAB scripts. We use the reported optima, not those illustrative defaults. The public linear script has tmax=10 whereas the paper uses 10^7; neither is evidence that ten steps suffice.

## Extension assumptions

1. Four persistent agents in one group per independent chain. No rematching, role switch, cross-session memory, or communication.
2. Each agent observes q_i = mean(c_j/e_j for j != i) from the PREVIOUS round. This is an unweighted mean of others' relative contributions, not sum(c)/sum(e), and not their productive contributions. SI Fig. S23 instead describes experimental conditional behavior against others' effective contribution; the chosen signal is a modeling restriction.
3. Baseline reactive lookup has 13 signal levels (0,1/12,...,1). The nearest level selects the action, with half-way values rounded upwards. There is one separate initial action. A 25-level sensitivity changes this discretization. No monotonicity is imposed: strategies permit reciprocity but need not be reciprocal.
4. Extend Eq.4 by averaging pairwise discrepancies: u_i=pi_i-beta*mean_j!=i(|c_i-c_j|)/max(e)-gamma*mean_j!=i(|c_i/e_i-c_j/e_j|). Mean of absolute differences is deliberately used, not absolute deviation from the mean. It reduces exactly to the paper's dyadic formula when n=2 and keeps preference scale from growing mechanically with group size.
5. Transfer the above (s,beta,gamma) unchanged. No four-player outcome is used to choose parameters or initialization. Initial and candidate lookup entries are independent discrete uniform draws; identical candidate strategies are redrawn.
6. Each revision selects one of four agents uniformly. All four contributions within a round use the same previous snapshot and are committed together. Strategy revision itself is asynchronous, as in the original mechanism.
7. Finite Monte Carlo budget and discarded warm-up are computational choices. Main configuration: 32 independent seed streams per cell, 6000 revision steps, first 2000 discarded, retain every 100th profile (40 profiles/chain), 20 rounds/profile. Estimates weight chains equally. Serially correlated retained profiles are never counted as independent Monte Carlo runs. This is far shorter than 10^7; stationarity is not assumed.
8. Sensitivity checks change signal resolution, initial strategies, run length, and fairness mechanism. They are diagnostics, not a search for the best experimental fit.

## State transition and pseudocode

`seed -> initial strategy profile -> synchronous 20-round episode -> one random focal agent -> whole alternative strategy -> full counterfactual episode -> logistic accept/reject -> next profile -> repeat`

```
for treatment and independent seed:
    draw four strategies; evaluate their full episode
    for revision_step:
        choose one agent uniformly; draw a different complete candidate strategy
        evaluate all four players under the alternative profile from round 1
        accept with logistic(s * (candidate mean utility - current mean utility))
        retain either the entire alternative profile/episode or the entire current one
        record diagnostics; after warm-up save scheduled episode snapshots
```

## Outcomes, uncertainty and possible failures

Agent observations: run x retained revision x round x agent. Group metrics: weighted group relative contribution sum(c)/sum(e); surplus (sum(payoff)-sum(e))/sum(e); Gini of monetary payoff; threshold success. Gini is defined as 0 for an all-zero nonnegative payoff vector, a mathematical boundary convention (not anticipated in these six cells).

Experimental estimates: each group-session's 20-round average, then treatment means. Sessions reuse participants, so pooled group-sessions are not guaranteed independent. Report descriptive pooled means and a session-1-only check; no pooled iid confidence intervals or treatment p-values. Simulation confidence intervals quantify Monte Carlo uncertainty across independent chain means only, conditional on the chosen finite algorithm; they do not quantify model uncertainty.

Hypotheses, not results: linear alignment can raise surplus without raising raw contribution, while fairness and group coordination may have different effects in threshold games. The transferred model may fail completely. Check payoff arithmetic, integer bounds, conserved roster, joint counterfactual responses, reproducibility, permutation invariance, iteration order, zero/full contributions, threshold equality, no-fairness and neutral selection, seed dispersion, initialization and finite-length dependence before interpreting patterns. Persistent initial-condition effects or drift mean longer simulation/model review is needed, not evidence of equilibrium or robust emergence.
