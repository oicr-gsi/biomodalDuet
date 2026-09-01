# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-01
### Added
- `scheduler`, `slurmPartition`, `slurmAccount`, `singularityBinds` and
  `processBeforeScript`, so the workflow runs on slurm as well as sge. `scheduler` is
  resolved from the submit command the cluster provides when left empty, and decided
  before any work is done, so a setting that cannot be satisfied fails at once rather
  than after alignment.
- With slurm the task writes the executor settings itself and appends them last, so no
  config file has to be placed on the cluster. It replaces `clusterOptions` for every
  `withName` selector that sets it, not just the generic one: a generic assignment does
  not reach a selector, and the pipeline config sets that directive in the other
  scheduler's syntax, which sbatch rejects. The selectors are found rather than listed,
  so a pipeline upgrade that adds one is still covered.
- The generated settings restore the pipeline's own `beforeScript` and input paths. The
  instance override loads the modules of the site it was configured for, and the slurm
  profile points `data_path` and `reference_path` at the vendor's demo installation;
  both are wrong anywhere else.

## [1.0.1] - 2026-06-18
### Added
- Nextflow paramas as wdl params, to make the nextflow params configurable in wdl

## [1.0.0] - 2026-05-19
### Added
- A brand-new workflow.
