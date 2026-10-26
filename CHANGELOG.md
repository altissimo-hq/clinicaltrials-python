# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The package version is the ClinicalTrials.gov API version it was generated
from. A regeneration that doesn't change the API version gets a post-release
suffix (for example `2.0.5.post1`).

## [Unreleased]

## [2.0.5] - 2026-10-26

First release published to PyPI, as `altissimo-clinicaltrials`. The import name
is `clinicaltrials`. The repository moved from `everygene/clinicaltrials-python`
to `altissimo-hq/clinicaltrials-python`.

### Changed

- Generated from ClinicalTrials.gov API 2.0.5 (was 2.0.3). In the client:
  - `nct_id` and `nct_id_aliases` are validated as 11-character NCT numbers
    (they were unconstrained strings).
  - `DesignModule.n_ptrs_to_this_exp_acc_nct_id` is an `int` (was `float | int`).
- Licensed under Apache-2.0.
- `generate.sh` keeps the spec committed (`--update-spec` downloads the current
  one), removes files from the previous generation before regenerating, and sets
  the PyPI name and authors in `pyproject.toml`.
- CI and publishing use hand-maintained workflows (`ci.yml`, `publish.yaml`)
  instead of the generator's `python.yml`, `.travis.yml` and `.gitlab-ci.yml`.

### Removed

- `Location.country_code`, which ClinicalTrials.gov removed from the API.
