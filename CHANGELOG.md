# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-11-17
### Fixed
- The instance config's `beforeScript` is replaced rather than left in place. It loads one
  named build of the container runtime from one named OS tree, and on another tree that is
  a build the site has not granted the unprivileged namespace to, so every process is
  refused with `Failed to create container process`. The module's own dependency already
  provides the right build.

### Changed
- `biomodal-duet/1.5.0.1`, which runs the pipeline under apptainer rather than singularity
  3.9.4. The same software; only the container runtime differs.
- The workflow no longer steers where the container runtime unpacks an image. Apptainer
  mounts a SIF rather than unpacking it, so the directory it would have unpacked into does
  not arise, and the module now provides apptainer. Nothing of ours runs before a Nextflow
  process any more: the temporary directory bound into the container carries its own
  default where the bind is written, and `beforeScript` is emitted only for the pipeline's
  own or the caller's `processBeforeScript`.

## [1.1.0] - 2026-09-01
### Added
- `scheduler`, `slurmPartition`, `slurmAccount`, `singularityBinds`,
  `processBeforeScript` and `processTime`, so the workflow runs on slurm as well as sge. `scheduler` is
  resolved from the submit command the cluster provides when left empty, and decided
  before any work is done, so a setting that cannot be satisfied fails at once rather
  than after alignment.
- With slurm the task writes the executor settings itself and appends them last, so no
  config file has to be placed on the cluster. It replaces `clusterOptions` for every
  `withName` selector that sets it, not just the generic one: a generic assignment does
  not reach a selector, and the pipeline config sets that directive in the other
  scheduler's syntax, which sbatch rejects. The selectors are found rather than listed,
  so a pipeline upgrade that adds one is still covered.
- `processTime` caps the wall-clock limit of every Nextflow process, on the generic
  scope and on each selector that sets one. The configs in place ask for 24h, and 48h for
  the two longest processes, which a partition with a lower limit rejects at submit.
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
