#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

cd "$1"

ls | sed 's/.*\.//' | sort | uniq -c
cat test_01.metrics_definitions.csv | sort | md5sum
cat test_01.summary.csv | sort | md5sum
zcat test_01.hmc_cxreport.txt.gz | sort | md5sum
zcat test_01.mc_cxreport.txt.gz | sort | md5sum
zcat test_01.modc_cxreport.txt.gz | sort | md5sum
zcat test_01.vcf.gz | grep -v "^#" | sort | md5sum