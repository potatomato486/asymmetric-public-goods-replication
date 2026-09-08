# Four-player asymmetric public-goods ABM extension

A runnable computational extension of the existing R partial replication of Wang, Hilbe & Zhang (2026). It transfers the paper's two-player reactive-strategy/introspection mechanism to four-player groups and compares it against the actual four-player experimental data. **The MVP runs, but the transferred model does not reproduce all treatment patterns and finite-chain initialization dependence remains.**

Start with [RESULTS.md](RESULTS.md), the [comparison figure](output/figures/experimental_vs_simulation.png), and the [model specification](docs/MODEL_SPEC.md). The Chinese [learning review](docs/LEARNING_REVIEW.md) separates runnable artifacts from the user's as-yet-unverified independent mastery.

## Evidence and scope

- All six FE / AI / MI x linear / threshold settings are verified against supplement Table S15, p.14. Thresholds are explicitly 48 / 120 / 72, with reward 20 per person; no four-player threshold was invented.
- Reactive deterministic integer strategies, synchronous actions, one focal strategy revision per time step, and full counterfactual episodes. The group signal and four-player fairness formula are **extension assumptions**.
- Baseline: 32 independent seeds per cell, 6,000 revisions, 2,000 discarded, 20-round episodes. Chain summaries use every post-warm-up profile; tidy snapshots save every 100th profile. The baseline exports 614,400 agent-round and 153,600 group-round rows.
- Six prespecified sensitivity variants: 25 signal levels, minimum signal, zero/full initial profiles, 12,000 revisions, and no fairness. Each uses 16 seeds per cell. These are diagnostics, not calibration candidates.
- Experimental data: 12,480 linear and 11,040 threshold player-round records, reduced to 156 and 138 group-sessions without dropping observations. The linear MAT table equals the original project's CSV cell-for-cell. All six aggregate benchmarks agree with the supplement within rounding.
- Verification tests, file hashes, seed/config manifests, export round-trip checks, R figures and R environment record are included. Monte Carlo intervals measure across-seed uncertainty of finite-run means; convergence and model adequacy are separate questions.

## Run locally or in Colab

Requires Python 3.12 (tested), NumPy and pandas. R 4.4.1 and ggplot2 were used for the included analysis. No Mesa or notebook is required.

From this directory:

```sh
python -m pip install -r requirements.txt
python -W error -m unittest discover -s tests -v
python -u -W error run_experiments.py --suite baseline
python -W error verify_exports.py
Rscript --vanilla R/analyze_extension.R
```

To regenerate source data (only needed when raw/processed inputs are absent):

```sh
python -m pip install -r requirements-data.txt
python fetch_references.py
python prepare_data.py --existing-linear ../data/LinearPGG_4P_ExperimentalData.csv
```

The data decoder is intentionally restricted to the checksum-pinned author MATLAB files. It uses SciPy's private MATLAB reader, pinned in requirements-data.txt, and verifies the extracted field names and dimensions. It is not a general table converter. A full linear-cell comparison with the preexisting project CSV is required before threshold data are used.

Sensitivity runs and final R comparison:

```sh
python -u -W error run_experiments.py --suite sensitivity
Rscript --vanilla R/analyze_extension.R --sensitivity
```

The runner is deterministic for the recorded versions/seeds. Running it again replaces derived files for that suite/cell; it never touches raw data. `manifest.json` is marked running before a cell and complete only after all outputs are written and hashed. Archived full runs are not required to install dependencies or access credentials.

On Windows, if R reports an unsupported C.UTF-8 startup locale, set `LC_ALL=C` and `LANG=C` for that process. The final recorded R runs used this setting and promote subsequent warnings to errors. If a network proxy is necessary for source download, pass `--proxy URL` to fetch_references.py; no proxy is assumed by the model.

## Files and units

| File | Purpose / unit |
|---|---|
| `abm/game.py` | Verified payoff rules and explicitly extended fairness |
| `abm/strategies.py` | Integer actions; previous-round group signal |
| `abm/simulation.py` | Episode and independent seed chains |
| `run_experiments.py` | Prespecified suites, manifests, CSV exports |
| `prepare_data.py` | Read-only source conversion and validation |
| `verify_exports.py` | Re-read CSVs and reconcile agent/group outcomes |
| `tests/test_model.py` | Arithmetic, boundary, counterfactual, seed and schedule tests |
| `R/analyze_extension.R` | Group summaries, Monte Carlo intervals and plots |
| `output/comparison.csv` | One game x treatment x outcome; experimental vs simulation |
| `output/*/*/agent_round.csv` | Run x retained revision x round x agent |
| `output/*/*/group_round.csv` | Run x retained revision x round |
| `output/*/*/chain_summary.csv` | Independent seed; all post-warm-up profile means |
| `output/*/*/learning_blocks.csv` | Seed x revision window |
| `output/*/*/strategies.npz` | Exact initial/final lookup profiles and seeds |
| `reference/source_manifest.json` | Source URLs, licenses and checksums |

Every simulated row includes run ID, seed, treatment, game, learning controls and time indices. Agent rows additionally contain endowment, productivity, contribution, payoff, utility and fairness gaps. Threshold/reward are in each cell's manifest. `success` is inapplicable (blank) for linear group records; threshold snapshot CSVs encode it as True/False, explicitly parsed by the R script. No other missing values are expected. Mean chain utilities and preferences have no causal interpretation.

## Attribution and limitations

Wang, X., Hilbe, C., & Zhang, B. (2026). *The dynamics of cooperation in asymmetric public goods games*. PNAS 123(5), e2525760123. [Article](https://doi.org/10.1073/pnas.2525760123); [author data and code](https://doi.org/10.5281/zenodo.16918146), CC BY 4.0. Source locations and differences from the author MATLAB defaults are documented in docs/MODEL_SPEC.md.

The originally mentioned uploaded `/mnt/data/pnas.202525760.pdf` was not accessible in the Windows project mirror. This work uses the author-hosted final article plus the public SI; no claim of byte identity with the upload is made. Original synced sources and the parent replication data/scripts are preserved.

The experiment reshuffles groups and swaps roles across two sessions; this MVP models a fixed group and does not fit cross-session learning. Pooled experimental means are descriptive, with session-specific means supplied; reused participants are not silently treated as independent. Paper-calibrated dyadic parameters are transferred unchanged, but the group's signal discretization, preference aggregation, proposal space and finite runtime can affect results. Further user learning, longer-run mixing diagnosis and alternative prespecified mechanisms remain necessary.
