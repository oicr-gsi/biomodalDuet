version 1.0

workflow biomodalDuet {
    input {
        Array[File] fastqR1
        Array[File] fastqR2
        String sampleId
        String runName
        String outputFileNamePrefix
        String mode = "6bp"
        String modules = "biomodal-duet/1.5.0"
    }

    parameter_meta {
        fastqR1:                "Array of R1 FASTQ files (all lanes for one sample)"
        fastqR2:                "Array of R2 FASTQ files (all lanes for one sample)"
        sampleId:               "Sample identifier (used for naming output files)"
        runName:                "Sequencing run name / flowcell ID"
        outputFileNamePrefix:   "Prefix for all output file names"
        mode:                   "Biomodal DUET mode (default: 6bp)"
        additionalProfile:      "Nextflow profile to apply (default: deep_seq)"
        modules:                "Environment modules to load"
    }

    call runDuet {
        input:
            fastqR1              = fastqR1,
            fastqR2              = fastqR2,
            sampleId             = sampleId,
            runName              = runName,
            outputFileNamePrefix = outputFileNamePrefix,
            mode                 = mode,
            modules              = modules
    }

    meta {
        author: "Gavin Peng"
        email: "gpeng@oicr.on.ca"
        description: "WDL wrapper for the Biomodal DUET methylation sequencing pipeline v1.5.0"
        dependencies: [
            {
                name: "biomodal-duet/1.5.0",
                url: "https://biomodal.com"
            }
        ]
        output_meta: {
            outputBam: {
                description: "Deduplicated, coordinate-sorted BAM file of aligned reads",
                vidarr_label: "outputBam"
            },
            outputBai:  {
                description: "BAM index (.bai) for random-access retrieval of the deduplicated BAM",
                vidarr_label: "outputBai"
            },         
            hmc_cxreport:  {
                description: "Cytosine Report for 5-hydroxymethylcytosine (5hmC) at CpG sites. Tab-separated, one row per stranded CpG position; columns report chromosome, position, strand, methylated-read count, unmethylated-read count, and context (CG). Suitable for downstream epigenetic analysis tools (e.g. methylKit, DSS). Gzip-compressed.",
                vidarr_label: "hmc_cxreport"
            },      
            hmc_cxreportIndex: {
                description: "Tabix index (.tbi) for the 5hmC Cytosine Report, enabling fast random-access queries by genomic region",
                viarr_label: "hmc_cxreportIndex"
            },
            mc_cxreport:  {
                description: "Cytosine Report for 5-methylcytosine (5mC) at CpG sites. Same tab-separated, per-stranded-CpG format as the 5hmC report; columns give chromosome, position, strand, methylated-read count, unmethylated-read count, and context (CG). Suitable for downstream epigenetic analysis tools (e.g. methylKit, DSS). Gzip-compressed.",
                vidarr_label: "mc_cxreport"
            },
            mc_cxreportIndex: {
                description: "Tabix index (.tbi) for the 5mC Cytosine Report, enabling fast random-access queries by genomic region",
                vidarr_label: "mc_cxreportIndex"
            },
            modc_cxreport: {
                description: "Cytosine Report for total modified cytosine (5mC + 5hmC combined, modC) at CpG sites. Same tab-separated, per-stranded-CpG format; provides an aggregate modification signal across both marks. Gzip-compressed.",
                vidarr_label: "modc_cxreport"
            }, 
            modc_cxreportIndex: {
                description: "Tabix index (.tbi) for the modC Cytosine Report, enabling fast random-access queries by genomic region",
                vidarr_label: "modc_cxreportIndex"
            },
            vcf: {
                description: "Germline variant calls VCF (optional; absent when no variants are called)",
                vidarr_label: "vcf"
            },
            vcfIndex: {
                description: "Tabix index (.tbi) for the germline VCF (optional)",
                vidarr_label: "vcfIndex"
            },
            summaryCsv: {
                description: "Run-level DUET summary metrics in CSV format",
                vidarr_label: "summaryCsv"
            },
            summaryHtml: {
                description: "Run-level DUET summary metrics as an interactive HTML report",
                vidarr_label: "summaryHtml"
            },
            summaryXlsx: {
                description: "Run-level DUET summary metrics in Excel format",
                vidarr_label: "summaryXlsx"
            },
            multiqcReport: {
                description: "MultiQC HTML report aggregating QC metrics across all pipeline steps",
                vidarr_label: "multiqcReport"
            },
            metricsDefinitions: {
                description: "CSV file defining and describing each metric reported in the summary outputs",
                vidarr_label: "metricsDefinitions"
            }
        }
    }

    output {
        File    outputBam          = runDuet.outputBam
        File    outputBai          = runDuet.outputBai
        File    hmc_cxreport       = runDuet.hmc_cxreport
        File    hmc_cxreportIndex  = runDuet.hmc_cxreportIndex
        File    mc_cxreport        = runDuet.mc_cxreport
        File    mc_cxreportIndex   = runDuet.mc_cxreportIndex
        File    modc_cxreport      = runDuet.modc_cxreport
        File    modc_cxreportIndex = runDuet.modc_cxreportIndex
        File?   vcf                = runDuet.vcf
        File?   vcfIndex           = runDuet.vcfIndex
        File    summaryCsv         = runDuet.summaryCsv
        File    summaryHtml        = runDuet.summaryHtml
        File    summaryXlsx        = runDuet.summaryXlsx
        File    multiqcReport      = runDuet.multiqcReport
        File    metricsDefinitions = runDuet.metricsDefinitions
    }
}

task runDuet {
    input {
        Array[File] fastqR1
        Array[File] fastqR2
        String sampleId
        String runName
        String outputFileNamePrefix
        String mode
        String additionalProfile = "deep_seq"
        String modules
        Int    jobMemory = 16
        Int    timeout = 96
    }
    parameter_meta {
        fastqR1:              "Array of R1 FASTQ files (all lanes for one sample)"
        fastqR2:              "Array of R2 FASTQ files (all lanes for one sample)"
        sampleId:             "Sample identifier (used for naming output files)"
        runName:              "Sequencing run name / flowcell ID"
        outputFileNamePrefix: "Prefix for all output file names"
        mode:                 "Biomodal DUET mode (default: 6bp)"
        additionalProfile:    "Nextflow profile to apply (default: deep_seq)"
        modules:              "Environment modules to load"
        jobMemory:            "Memory in GB for head task"
        timeout:              "Timeout in hours"
    }

    command <<<
        set -euo pipefail

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
            type: sge
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

        # increase TSS_bias module memory
        cat >> "${INSTANCE_DIR}/nextflow_override.config" << NFEOF

process {
    withName: 'TSS_BIAS' {
        cpus   = 2
        memory = '32GB'
        time   = '24h'
    }
}
NFEOF
        # Resolve the canonical (symlink-free) path to the pipeline bin dir. Singularity won't follow symlink
        _BIN_REAL=$(realpath "${INSTANCE_DIR}/pipelines/duet/1.5.0/bin")
        cat >> "${INSTANCE_DIR}/nextflow_override.config" << NFEOF

singularity {
    runOptions = '--bind "\$TMPDIR:/tmp" --bind "${_BIN_REAL}:${_BIN_REAL}"'
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

    >>>

    runtime {
        memory:  "~{jobMemory} GB"
        timeout: "~{timeout}"
        modules: "~{modules}"
    }

    output {
        File    outputBam          = "~{outputFileNamePrefix}.bam"
        File    outputBai          = "~{outputFileNamePrefix}.bam.bai"
        File    hmc_cxreport       = "~{outputFileNamePrefix}.hmc_cxreport.txt.gz"
        File    hmc_cxreportIndex  = "~{outputFileNamePrefix}.hmc_cxreport.txt.gz.tbi"
        File    mc_cxreport        = "~{outputFileNamePrefix}.mc_cxreport.txt.gz"
        File    mc_cxreportIndex   = "~{outputFileNamePrefix}.mc_cxreport.txt.gz.tbi"
        File    modc_cxreport      = "~{outputFileNamePrefix}.modc_cxreport.txt.gz"
        File    modc_cxreportIndex = "~{outputFileNamePrefix}.modc_cxreport.txt.gz.tbi"
        File?   vcf                = "~{outputFileNamePrefix}.vcf.gz"
        File?   vcfIndex           = "~{outputFileNamePrefix}.vcf.gz.tbi"
        File    summaryCsv         = "~{outputFileNamePrefix}.summary.csv"
        File    summaryHtml        = "~{outputFileNamePrefix}.summary.html"
        File    summaryXlsx        = "~{outputFileNamePrefix}.summary.xlsx"
        File    multiqcReport      = "~{outputFileNamePrefix}.multiqc_report.html"
        File    metricsDefinitions = "~{outputFileNamePrefix}.metrics_definitions.csv"
    }
}
