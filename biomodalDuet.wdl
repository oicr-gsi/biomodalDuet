version 1.0

workflow biomodalDuet {
    input {
        Array[File] fastqR1
        Array[File] fastqR2
        String sampleId
        String runName
        String mode = "6bp"
    }

    parameter_meta {
        fastqR1:           "Array of R1 FASTQ files (all lanes for one sample)"
        fastqR2:           "Array of R2 FASTQ files (all lanes for one sample)"
        sampleId:          "Sample identifier (used for naming output files)"
        runName:           "Sequencing run name / flowcell ID"
        mode:              "Biomodal DUET mode (default: 6bp)"
        additionalProfile: "Nextflow profile to apply (default: deep_seq)"
    }

    call runDuet {
        input:
            fastqR1           = fastqR1,
            fastqR2           = fastqR2,
            sampleId          = sampleId,
            runName           = runName,
            mode              = mode
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
            outputBam:           "Deduplicated BAM file",
            outputBai:           "BAM index file",
            hmc_cxreport:        "5-hydroxymethylcytosine CX report (gz)",
            hmc_cxreportIndex:   "Index for hmc CX report",
            mc_cxreport:         "5-methylcytosine CX report (gz)",
            mc_cxreportIndex:    "Index for mc CX report",
            modc_cxreport:       "Modified cytosine CX report (gz)",
            modc_cxreportIndex:  "Index for modc CX report",
            vcf:                 "Germline variant calls VCF (optional)",
            vcfIndex:            "VCF index (optional)",
            summaryCsv:          "Run-level summary CSV",
            summaryHtml:         "Run-level summary HTML report",
            summaryXlsx:         "Run-level summary Excel report",
            multiqcReport:       "MultiQC HTML report",
            metricsDefinitions:  "Metrics definitions CSV"
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
        String mode
        String additionalProfile = "deep_seq"
        Int    jobMemory = 16
        Int    timeout = 96
    }

    command <<<
        set -euo pipefail
        module use /.mounts/labs/gsiprojects/gsi/gsiusers/gpeng/modules/local/gsi/modulator/modulefiles/Ubuntu20.04
        module load biomodal-duet/1.5.0

        BIOMODAL_INSTANCE_DIR="/.mounts/labs/gsiprojects/gsi/gsiusers/gpeng/modules/local/gsi/modulator/sw/Ubuntu20.04/biomodal-duet-1.5.0/duet-instance"
        BIOMODAL_IMAGES_DIR="/.mounts/labs/gsiprojects/gsi/gsiusers/gpeng/modules/local/gsi/modulator/sw/Ubuntu20.04/biomodal-duet-1.5.0/images"
        BIOMODAL_REF_DATA_DIR="/.mounts/labs/gsiprojects/gsi/gsiusers/gpeng/modules/local/gsi/modulator/sw/Ubuntu20.04/biomodal-duet-1.5.0/ref_data"
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

        cat >> "${INSTANCE_DIR}/nextflow_override.config" << NFEOF

        singularity {
        libraryDir = "${BIOMODAL_IMAGES_DIR}"
        cacheDir   = "${BIOMODAL_IMAGES_DIR}"
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
            base=$(basename "$r1")
            # Extract lane: single integer before barcode pattern _N_XXXX-XXXX_R1
            lane_num=$(echo "$base" | grep -oP '_\K\d+(?=_[A-Z]+-[A-Z]+_R[12])' | head -1)
            if [ -z "${lane_num}" ]; then
                lane_num=$((i+1))
            fi
            lane=$(printf 'L%03d' "${lane_num}")
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
        # Locate results subdirectory: nf-results/<sample>/<duet-version_sample_mode>/
        # ---------------------------------------------------------------------------
        RESULTS_SUBDIR=$(find "$(pwd)/nf-results" -mindepth 2 -maxdepth 2 \
                           -type d -name "duet-*" | head -1)
        echo "Results subdir: ${RESULTS_SUBDIR}"

        GENOME_PREFIX="${SAMPLE_ID_DASH}.genome.GRCh38Decoy_primary_assembly.dedup"

        # BAMs
        ln -s "${RESULTS_SUBDIR}/sample_outputs/bams/${GENOME_PREFIX}.bam"     output.bam
        ln -s "${RESULTS_SUBDIR}/sample_outputs/bams/${GENOME_PREFIX}.bam.bai" output.bam.bai

        # modc quantification
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.hmc_cxreport.txt.gz"     hmc_cxreport.txt.gz
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.hmc_cxreport.txt.gz.tbi" hmc_cxreport.txt.gz.tbi
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.mc_cxreport.txt.gz"      mc_cxreport.txt.gz
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.mc_cxreport.txt.gz.tbi"  mc_cxreport.txt.gz.tbi
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.modc_cxreport.txt.gz"    modc_cxreport.txt.gz
        ln -s "${RESULTS_SUBDIR}/sample_outputs/modc_quantification/${GENOME_PREFIX}.CG.modc_cxreport.txt.gz.tbi" modc_cxreport.txt.gz.tbi

        # VCF (optional)
        VCF_FILE="${RESULTS_SUBDIR}/sample_outputs/variant_call_files/germline/${GENOME_PREFIX}.output.vcf.gz"
        if [ -f "${VCF_FILE}" ]; then
            ln -s "${VCF_FILE}"       output.vcf.gz
            ln -s "${VCF_FILE}.tbi"   output.vcf.gz.tbi
        else
            touch output.vcf.gz output.vcf.gz.tbi
        fi

        # Reports
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.csv"             summary.csv
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.html"            summary.html
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Summary.xlsx"            summary.xlsx
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_multiqc_report.html"               multiqc_report.html
        ln -s "${RESULTS_SUBDIR}/reports/${RUN_NAME}_duet-evoC_Metrics_Definitions.csv" metrics_definitions.csv

    >>>

    runtime {
        memory:  "~{jobMemory} GB"
        timeout: "~{timeout}"
    }

    output {
        File    outputBam          = "output.bam"
        File    outputBai          = "output.bam.bai"
        File    hmc_cxreport       = "hmc_cxreport.txt.gz"
        File    hmc_cxreportIndex  = "hmc_cxreport.txt.gz.tbi"
        File    mc_cxreport        = "mc_cxreport.txt.gz"
        File    mc_cxreportIndex   = "mc_cxreport.txt.gz.tbi"
        File    modc_cxreport      = "modc_cxreport.txt.gz"
        File    modc_cxreportIndex = "modc_cxreport.txt.gz.tbi"
        File    vcf                = "output.vcf.gz"
        File    vcfIndex           = "output.vcf.gz.tbi"
        File    summaryCsv         = "summary.csv"
        File    summaryHtml        = "summary.html"
        File    summaryXlsx        = "summary.xlsx"
        File    multiqcReport      = "multiqc_report.html"
        File    metricsDefinitions = "metrics_definitions.csv"
    }

    parameter_meta {
        fastqR1:           "Array of R1 FASTQ files"
        fastqR2:           "Array of R2 FASTQ files"
        sampleId:          "Sample identifier"
        runName:           "Sequencing run name"
        mode:              "Biomodal DUET mode"
        additionalProfile: "Nextflow additional profile"
        jobMemory:         "Memory in GB for head task"
        timeout:           "Timeout in hours"
    }
}
