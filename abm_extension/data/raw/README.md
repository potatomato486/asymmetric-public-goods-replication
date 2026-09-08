# Raw input policy

Raw experimental input is read-only. Generated CSV copies are byte-checked before reuse and never silently overwritten. No observations were filtered from the supplied first-20-round data. The original project CSV remains untouched.

Wang, Xiaomin; Hilbe, Christian; Zhang, Boyu (2026), *The dynamics of cooperation in asymmetric public goods games*, PNAS 123(5), e2525760123. Article: https://doi.org/10.1073/pnas.2525760123 . Author data and code: https://doi.org/10.5281/zenodo.16918146 (CC BY 4.0).

`fetch_references.py` downloads the pinned deposited MAT files to reference/. `prepare_data.py` decodes those file-specific tables, validates all cells of the linear table against the existing local replication CSV, then creates `linear_experimental.csv` and `threshold_experimental.csv` here. See output/data_audit.json for hashes, row counts and source checks. Raw inputs are excluded from Git by default, matching the parent repository's data policy.

The Zenodo description says GroupID is globally unique; the actual files show reuse across treatments. Therefore use Treatment + Session + GroupID. GlobalPlayerID identifies participant-session combinations; it cannot link the same person between sessions. No claim of 624 or 552 distinct human participants is made.
