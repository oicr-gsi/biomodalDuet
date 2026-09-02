# biomodalDuet

## Overview

WDL wrapper for the Biomodal DUET methylation sequencing pipeline v1.5.0

## Dependencies

* [biomodal-duet 1.5.0](https://biomodal.com)


## Usage

### Cromwell
```
java -jar cromwell.jar run biomodalDuet.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`fastqR1`|Array[File]|Array of R1 FASTQ files (all lanes for one sample)
`fastqR2`|Array[File]|Array of R2 FASTQ files (all lanes for one sample)
`sampleId`|String|Sample identifier (used for naming output files)
`runName`|String|Sequencing run name / flowcell ID
`outputFileNamePrefix`|String|Prefix for all output file names


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`mode`|String|"6bp"|Biomodal DUET mode (default: 6bp)
`scheduler`|String|""|Which scheduler Nextflow submits its own jobs to, sge or slurm. Leave empty and the task decides from the submit command the cluster provides, so one set of inputs is portable between sites
`slurmPartition`|String|""|Partition Nextflow submits its own jobs to, required when scheduler resolves to slurm. The pipeline's slurm profile names a queue that exists only at the vendor's own site
`slurmAccount`|String|""|Accounting group for the jobs Nextflow submits, when the site requires one
`singularityBinds`|Array[String]|[]|Extra paths bound into every container, added to the binds the task already sets
`processBeforeScript`|String|""|Script run before every Nextflow process, replacing the one the instance config sets. Empty keeps the pipeline's own, which is what a site other than the one the instance was configured for needs
`processTime`|String|""|Wall-clock limit for every Nextflow process, as a Nextflow duration such as 24h, replacing the limits the configs in place set. Empty keeps those, which is only safe where they fit the partition or queue the jobs go to
`modules`|String|"biomodal-duet/1.5.0"|Environment modules to load


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`runDuet.additionalProfile`|String|"deep_seq"|Nextflow profile to apply (default: deep_seq)
`runDuet.jobMemory`|Int|16|Memory in GB for head task
`runDuet.timeout`|Int|96|Timeout in hours
`runDuet.preludeMemory`|Int|64|Memory (GB) for the PRELUDE process
`runDuet.bwaMem2Memory`|Int|64|Memory (GB) for the BWA_MEM2 alignment process
`runDuet.bamletMemory`|Int|32|Memory (GB) for the BAMLET process
`runDuet.haplotypeCallerMemory`|Int|64|Memory (GB) for the HAPLOTYPE_CALLER process
`runDuet.mutect2Memory`|Int|64|Memory (GB) for the MUTECT2 process
`runDuet.seqtkSampleMemory`|Int|64|Memory (GB) for the SEQTK_SAMPLE subsampling process
`runDuet.samtoolsMergeLanesMemory`|Int|16|Memory (GB) for the SAMTOOLS_MERGE_LANES process (multi-lane samples)
`runDuet.tssBiasMemory`|Int|32|Memory (GB) for the TSS_BIAS process


### Outputs

Output | Type | Description | Labels
---|---|---|---
`outputBam`|File|Deduplicated, coordinate-sorted BAM file of aligned reads|vidarr_label: outputBam
`outputBai`|File|BAM index (.bai) for random-access retrieval of the deduplicated BAM|vidarr_label: outputBai
`hmc_cxreport`|File|Cytosine Report for 5-hydroxymethylcytosine (5hmC) at CpG sites. Tab-separated, one row per stranded CpG position; columns report chromosome, position, strand, methylated-read count, unmethylated-read count, and context (CG). Suitable for downstream epigenetic analysis tools (e.g. methylKit, DSS). Gzip-compressed.|vidarr_label: hmc_cxreport
`hmc_cxreportIndex`|File|Tabix index (.tbi) for the 5hmC Cytosine Report, enabling fast random-access queries by genomic region|
`mc_cxreport`|File|Cytosine Report for 5-methylcytosine (5mC) at CpG sites. Same tab-separated, per-stranded-CpG format as the 5hmC report; columns give chromosome, position, strand, methylated-read count, unmethylated-read count, and context (CG). Suitable for downstream epigenetic analysis tools (e.g. methylKit, DSS). Gzip-compressed.|vidarr_label: mc_cxreport
`mc_cxreportIndex`|File|Tabix index (.tbi) for the 5mC Cytosine Report, enabling fast random-access queries by genomic region|vidarr_label: mc_cxreportIndex
`modc_cxreport`|File|Cytosine Report for total modified cytosine (5mC + 5hmC combined, modC) at CpG sites. Same tab-separated, per-stranded-CpG format; provides an aggregate modification signal across both marks. Gzip-compressed.|vidarr_label: modc_cxreport
`modc_cxreportIndex`|File|Tabix index (.tbi) for the modC Cytosine Report, enabling fast random-access queries by genomic region|vidarr_label: modc_cxreportIndex
`vcf`|File?|Germline variant calls VCF (optional; absent when no variants are called)|vidarr_label: vcf
`vcfIndex`|File?|Tabix index (.tbi) for the germline VCF (optional)|vidarr_label: vcfIndex
`summaryCsv`|File|Run-level DUET summary metrics in CSV format|vidarr_label: summaryCsv
`summaryHtml`|File|Run-level DUET summary metrics as an interactive HTML report|vidarr_label: summaryHtml
`summaryXlsx`|File|Run-level DUET summary metrics in Excel format|vidarr_label: summaryXlsx
`multiqcReport`|File|MultiQC HTML report aggregating QC metrics across all pipeline steps|vidarr_label: multiqcReport
`metricsDefinitions`|File|CSV file defining and describing each metric reported in the summary outputs|vidarr_label: metricsDefinitions


## Commands
This section lists command(s) run by biomodalDuet workflow

* Running biomodalDuet

```
        set -euo pipefail

        # ---------------------------------------------------------------------------
        # Which scheduler Nextflow submits its own jobs to. Resolved from the submit
        # command the cluster provides so one set of inputs is portable between sites;
        # the scheduler input overrides that. Decided before any work is done, so a
        # setting that cannot be satisfied fails immediately rather than after alignment.
        # ---------------------------------------------------------------------------
        SCHEDULER="~{scheduler}"
        if [ -z "${SCHEDULER}" ]; then
            if   command -v sbatch >/dev/null 2>&1; then SCHEDULER=slurm
            elif command -v qsub   >/dev/null 2>&1; then SCHEDULER=sge
            else
                echo "ERROR: cannot tell which scheduler Nextflow should submit to: neither sbatch nor qsub is on PATH. Set the scheduler input" >&2
                exit 1
            fi
            echo "Detected scheduler: ${SCHEDULER}"
        fi

        SLURM_ONLY=()
        [ -z "~{slurmPartition}" ]      || SLURM_ONLY+=("slurmPartition")
        [ -z "~{slurmAccount}" ]        || SLURM_ONLY+=("slurmAccount")
        [ -z "~{processBeforeScript}" ] || SLURM_ONLY+=("processBeforeScript")

        case "${SCHEDULER}" in
            sge)
                # Ignored rather than refused, so one set of inputs can carry them and
                # still run where they do not apply.
                if [ "${#SLURM_ONLY[@]}" -gt 0 ]; then
                    echo "Note: $(IFS=,; echo "${SLURM_ONLY[*]}") ignored; those apply only to slurm"
                fi
                ;;
            slurm)
                if [ -z "~{slurmPartition}" ]; then
                    echo "ERROR: scheduler slurm requires slurmPartition: the pipeline's slurm profile names a queue that does not exist here" >&2
                    exit 1
                fi
                ;;
            *)
                echo "ERROR: scheduler must be sge or slurm, got '${SCHEDULER}'" >&2
                exit 1
                ;;
        esac

        mkdir -p biomodal_instance
        ln -s $BIOMODAL_INSTANCE_DIR/* ./biomodal_instance
        # Replace symlinks with real writable copies
        cp -L --remove-destination $BIOMODAL_INSTANCE_DIR/cli_config.yaml ./biomodal_instance/cli_config.yaml
        cp -L --remove-destination $BIOMODAL_INSTANCE_DIR/nextflow_override.config .//biomodal_instance/nextflow_override.config
        chmod 770 ./biomodal_instance/cli_config.yaml .//biomodal_instance/nextflow_override.config
        INSTANCE_DIR="$(pwd)/biomodal_instance"

        # Rewrite cli_config.yaml with runtime paths
        cat > "${INSTANCE_DIR}/cli_config.yaml" << CLIEOF
        cli:
            max_concurrent_transfers: 6
            max_retries: 3
        computing_platform:
            container_engine: singularity
            error_strategy: fail_fast
            images_registry_location: ${BIOMODAL_IMAGES_DIR}
            nextflow_work_directory_location: $(pwd)/work
            reference_files_location: ${BIOMODAL_REF_DATA_DIR}
            type: ${SCHEDULER}
        pipelines:
            duet:
                version: 1.5.0
        telemetry:
            share_events: false
            share_metrics: false
CLIEOF

        # Unquoted heredoc: bash expands ${BIOMODAL_IMAGES_DIR} for libraryDir/cacheDir.
        cat >> "${INSTANCE_DIR}/nextflow_override.config" << NFEOF

singularity {
    libraryDir = "${BIOMODAL_IMAGES_DIR}"
    cacheDir   = "${BIOMODAL_IMAGES_DIR}"
}
NFEOF

        # Per-process memory overrides, driven by WDL task inputs so resource
        # allocations can be tuned per run without patching this WDL.
        cat >> "${INSTANCE_DIR}/nextflow_override.config" << 'NFEOF'

process {
    withName: 'PRELUDE'          { memory = '~{preludeMemory}GB' }
    withName: 'BWA_MEM2'         { memory = '~{bwaMem2Memory}GB' }
    withName: 'BAMLET'           { memory = '~{bamletMemory}GB' }
    withName: 'HAPLOTYPE_CALLER' { memory = '~{haplotypeCallerMemory}GB' }
    withName: 'MUTECT2'          { memory = '~{mutect2Memory}GB' }
    withName: 'SEQTK_SAMPLE'     { memory = '~{seqtkSampleMemory}GB' }
    withName: 'SAMTOOLS_MERGE_LANES' { memory = '~{samtoolsMergeLanesMemory}GB' }
    withName: 'TSS_BIAS'         { memory = '~{tssBiasMemory}GB' }
}
NFEOF
        # Resolve the canonical (symlink-free) path to the pipeline bin dir. Singularity won't follow symlink
        _BIN_REAL=$(realpath "${INSTANCE_DIR}/pipelines/duet/1.5.0/bin")
        # A later runOptions replaces the whole string rather than adding to it, so the
        # caller's binds are composed in here instead of being appended separately.
        _BINDS=(~{sep=' ' singularityBinds})
        _EXTRA_BINDS=""
        if [ "${#_BINDS[@]}" -gt 0 ]; then
            for _b in "${_BINDS[@]}"; do
                _EXTRA_BINDS="${_EXTRA_BINDS} --bind \"${_b}\""
            done
        fi
        cat >> "${INSTANCE_DIR}/nextflow_override.config" << NFEOF

singularity {
    runOptions = '--bind "\$TMPDIR:/tmp" --bind "${_BIN_REAL}:${_BIN_REAL}"${_EXTRA_BINDS}'
}
NFEOF

        CONFIG_PATH="${INSTANCE_DIR}/nextflow_override.config" python3 <<'PYEOF'
import re, pathlib, os
p = pathlib.Path(os.environ["CONFIG_PATH"])
content = p.read_text()
content = re.sub(
    r"params \{\s*\n\s*registry = '[^']*'\s*\n\}\n",
    "",
    content,
    count=1
)
p.write_text(content)
PYEOF

        # ---------------------------------------------------------------------------
        # Scheduler and wall-time settings, appended last so they win over both the
        # pipeline config and the instance override above. Written per run rather than
        # kept in a file on the cluster, so the workflow carries what it needs to switch
        # scheduler. Nothing is written for an sge run that leaves processTime empty, so
        # that path keeps exactly the configs already in place.
        # ---------------------------------------------------------------------------
        SCHED_SCHEDULER="${SCHEDULER}" \
        SCHED_PARTITION="~{slurmPartition}" \
        SCHED_ACCOUNT="~{slurmAccount}" \
        SCHED_BEFORE="~{processBeforeScript}" \
        SCHED_TIME="~{processTime}" \
        SCHED_DATA_PATH="$(pwd)/nf-input" \
        SCHED_REFERENCE_PATH="${BIOMODAL_REF_DATA_DIR}/1.0.5_GRCh38Decoy" \
        SCHED_PIPELINE_CONFIG="${INSTANCE_DIR}/pipelines/duet/1.5.0/nextflow.config" \
        SCHED_OVERRIDE_CONFIG="${INSTANCE_DIR}/nextflow_override.config" \
        python3 <<'PYEOF'
import os, pathlib, re

sched = os.environ["SCHED_SCHEDULER"]
proc_time = os.environ["SCHED_TIME"]
pipeline_cfg = pathlib.Path(os.environ["SCHED_PIPELINE_CONFIG"]).read_text()
override = pathlib.Path(os.environ["SCHED_OVERRIDE_CONFIG"])
override_cfg = override.read_text()


def selectors_setting(directive):
    # A generic assignment does not reach a withName selector, so a directive already
    # set on a selector has to be replaced on that same selector. Found rather than
    # listed, so a pipeline upgrade that adds one is still covered.
    found = []
    for src in (pipeline_cfg, override_cfg):
        for m in re.finditer(r"withName:\s*'([^']+)'\s*\{([^{}]*)\}", src, re.S):
            if re.search(r"\b%s\s*=" % directive, m.group(2)) and m.group(1) not in found:
                found.append(m.group(1))
    return found


generic = []
per_selector = {}
notes = []


def on_selector(name, assignment):
    per_selector.setdefault(name, []).append(assignment)


if sched == "slurm":
    account = os.environ["SCHED_ACCOUNT"]
    cluster_opts = "--account=%s" % account if account else ""
    before = os.environ["SCHED_BEFORE"]
    if not before:
        # The instance override runs a beforeScript that loads the modules of the site
        # it was configured for, which cannot run elsewhere. Falling back to the
        # pipeline's own keeps what the pipeline needs while dropping what is site-bound.
        m = re.search(r"^\s*beforeScript\s*=\s*'{3}(.*?)'{3}", pipeline_cfg, re.S | re.M)
        before = m.group(1) if m else ""
    generic += [
        "executor = 'slurm'",
        "queue = '%s'" % os.environ["SCHED_PARTITION"],
        "clusterOptions = '%s'" % cluster_opts,
        "beforeScript = %s%s%s" % ("'" * 3, before, "'" * 3),
    ]
    # The configs in place set clusterOptions in the other scheduler's syntax, which
    # sbatch rejects.
    sel = selectors_setting("clusterOptions")
    for s in sel:
        on_selector(s, "clusterOptions = '%s'" % cluster_opts)
    notes.append("clusterOptions replaced for: %s" % (", ".join(sel) or "no selectors"))

if proc_time:
    generic.append("time = '%s'" % proc_time)
    sel = selectors_setting("time")
    for s in sel:
        on_selector(s, "time = '%s'" % proc_time)
    notes.append("time set to %s, including for: %s" % (proc_time, ", ".join(sel) or "no selectors"))

if generic or per_selector:
    lines = [
        "",
        "//////////////////////////////////////////////////////",
        "// ---- SCHEDULER SETTINGS (generated per run) ----",
        "process {",
    ]
    lines += ["    %s" % g for g in generic]
    lines += ["    withName: '%s' { %s }" % (s, "; ".join(a))
              for s, a in per_selector.items()]
    lines.append("}")
    if sched == "slurm":
        # The slurm profile points these at the vendor's own demo installation, where
        # the sge profile leaves them empty for the CLI to fill.
        lines += [
            "params {",
            "    data_path = '%s'" % os.environ["SCHED_DATA_PATH"],
            "    reference_path = '%s'" % os.environ["SCHED_REFERENCE_PATH"],
            "}",
        ]
    lines.append("")
    with override.open("a") as fh:
        fh.write("\n".join(lines))
    for n in notes:
        print("Scheduler settings: %s" % n)
PYEOF

        export NXF_HOME="$(pwd)/nxf_home"
        mkdir -p "${NXF_HOME}/framework/25.04.8"
        cp "${INSTANCE_DIR}/pipelines/duet/1.5.0/nextflow-25.04.8-one.jar" \
           "${NXF_HOME}/framework/25.04.8/"

        # ---------------------------------------------------------------------------
        # Build nf-input directory with Biomodal-format symlinks
        # Format: {sample-id-no-underscores}_S1_{L###}_{R1|R2}_001.fastq.gz
        # Lane number extracted from filename pattern _<N>_<BARCODE>_R[12]
        # ---------------------------------------------------------------------------
        SAMPLE_ID="~{sampleId}"
        RUN_NAME="~{runName}"
        SAMPLE_ID_DASH=$(echo "${SAMPLE_ID}" | tr '_' '-')
        mkdir -p nf-input

        sorted_R1=($(for f in ~{sep=' ' fastqR1}; do echo "$f"; done | sort))
        sorted_R2=($(for f in ~{sep=' ' fastqR2}; do echo "$f"; done | sort))

        if [ ${#sorted_R1[@]} -ne ${#sorted_R2[@]} ]; then
            echo "ERROR: R1 count (${#sorted_R1[@]}) != R2 count (${#sorted_R2[@]})" >&2
            exit 1
        fi

        for i in "${!sorted_R1[@]}"; do
            r1="${sorted_R1[$i]}"
            r2="${sorted_R2[$i]}"
            lane=$(printf 'L%03d' "$((i+1))")
            ln -s "${r1}" "nf-input/${SAMPLE_ID_DASH}_S1_${lane}_R1_001.fastq.gz"
            ln -s "${r2}" "nf-input/${SAMPLE_ID_DASH}_S1_${lane}_R2_001.fastq.gz"
            echo "Linked lane ${lane}: $(basename ${r1}) / $(basename ${r2})"
        done

        # ---------------------------------------------------------------------------
        # Run biomodal DUET
        # ---------------------------------------------------------------------------
        mkdir -p nf-results

        "${INSTANCE_DIR}"/biomodal run duet \
            --instance-directory "${INSTANCE_DIR}" \
            --work-dir "$(pwd)/work" \
            --input-path  "$(pwd)/nf-input" \
            --output-path "$(pwd)/nf-results" \
            --run-name    "${RUN_NAME}" \
            --tag         "${SAMPLE_ID_DASH}" \
            --additional-params lib_prefix="${SAMPLE_ID_DASH}" \
            --additional-params "with-report=$(pwd)/nf_report.html" \
            --additional-params "with-trace=$(pwd)/nf_trace.tsv" \
            --additional-params "log=$(pwd)/nextflow.log" \
            --additional-profile ~{additionalProfile} \
            --additional-params "singularity.cacheDir=${BIOMODAL_IMAGES_DIR}" \
            --additional-params registry='europe-docker.pkg.dev/cegx-releases/eu-prod' \
            --additional-params "reference_path=${BIOMODAL_REF_DATA_DIR}/1.0.5_GRCh38Decoy" \
            --mode ~{mode}

        # ---------------------------------------------------------------------------
        # Locate results subdirectory: nf-results/<duet-version_sample_mode>/
        # ---------------------------------------------------------------------------
        RESULTS_SUBDIR=$(find "$(pwd)/nf-results" -mindepth 1 -maxdepth 1 \
                           -type d -name "duet-*" | head -1)
        echo "Results subdir: ${RESULTS_SUBDIR}"

        GENOME_PREFIX="${SAMPLE_ID_DASH}.genome.GRCh38Decoy_primary_assembly.dedup"
        OUTPUT_PREFIX="~{outputFileNamePrefix}"

        # BAMs
        ln -s "${RESULTS_SUBDIR}/sample_outputs/bams/${GENOME_PREFIX}.bam"     "${OUTPUT_PREFIX}.bam"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/bams/${GENOME_PREFIX}.bam.bai" "${OUTPUT_PREFIX}.bam.bai"

        # modc quantification
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.hmc_cxreport.txt.gz"     "${OUTPUT_PREFIX}.hmc_cxreport.txt.gz"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.hmc_cxreport.txt.gz.tbi" "${OUTPUT_PREFIX}.hmc_cxreport.txt.gz.tbi"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.mc_cxreport.txt.gz"      "${OUTPUT_PREFIX}.mc_cxreport.txt.gz"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.mc_cxreport.txt.gz.tbi"  "${OUTPUT_PREFIX}.mc_cxreport.txt.gz.tbi"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.modc_cxreport.txt.gz"    "${OUTPUT_PREFIX}.modc_cxreport.txt.gz"
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.modc_cxreport.txt.gz.tbi" "${OUTPUT_PREFIX}.modc_cxreport.txt.gz.tbi"

        # VCF (optional)
        VCF_FILE="${RESULTS_SUBDIR}/sample_outputs/variant_call_files/germline/${GENOME_PREFIX}.output.vcf.gz"
        if [ -f "${VCF_FILE}" ]; then
            ln -s "${VCF_FILE}"       "${OUTPUT_PREFIX}.vcf.gz"
            ln -s "${VCF_FILE}.tbi"   "${OUTPUT_PREFIX}.vcf.gz.tbi"
        else
            touch "${OUTPUT_PREFIX}.vcf.gz" "${OUTPUT_PREFIX}.vcf.gz.tbi"
        fi

        # Reports
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.csv"             "${OUTPUT_PREFIX}.summary.csv"
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.html"            "${OUTPUT_PREFIX}.summary.html"
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.xlsx"            "${OUTPUT_PREFIX}.summary.xlsx"
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_multiqc_report.html"               "${OUTPUT_PREFIX}.multiqc_report.html"
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Metrics_Definitions.csv" "${OUTPUT_PREFIX}.metrics_definitions.csv"

```

## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
