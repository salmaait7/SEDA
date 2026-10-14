#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="${PROJECT_ROOT:-/home/salma/SEDA}"



CIRCUIT="${CIRCUIT:-c432}"

VERILOG_FILE="${VERILOG_FILE:-\
$PROJECT_ROOT/data/benchmarks/clean/${CIRCUIT}.v}"

DELAY_FILE="${DELAY_FILE:-\
$PROJECT_ROOT/config/delay_models/gate_delays_simplified.json}"

MARGINS="${MARGINS:-0.05,0.10,0.15,0.20}"
NUMBER_OF_RUNS="${NUMBER_OF_RUNS:-30}"

NB_VECTORS="${NB_VECTORS:-500}"
NB_CYCLES="${NB_CYCLES:-$NB_VECTORS}"

STEP_TIME_NS="${STEP_TIME_NS:-40.0}"
STIMULUS_SEED="${STIMULUS_SEED:-42}"


DEBUG_INTERNAL_SIGNALS="${DEBUG_INTERNAL_SIGNALS:-true}"

OUTPUTS_ONLY="${OUTPUTS_ONLY:-false}"

CAMPAIGN_NAME="${CAMPAIGN_NAME:-healthy_variation_fixed_delay_v2}"

GENERATOR="$PROJECT_ROOT/scripts/campaigns/generate_circuits.rb"

SIMULATOR="$PROJECT_ROOT/scripts/simulations/simulate_campaign.sh"

ANALYZER="$PROJECT_ROOT/scripts/analysis/analyze_vcd.rb"

COMPARATOR="$PROJECT_ROOT/scripts/analysis/compare_activity.rb"

SUMMARIZER="$PROJECT_ROOT/scripts/analysis/summarize_comparisons.rb"

GENERATED_ROOT="$PROJECT_ROOT/build"
VHDL_DIR="$GENERATED_ROOT/vhdl/circuits/$CIRCUIT"
DELAY_REPORT_DIR="$GENERATED_ROOT/delays/$CIRCUIT"
TB_FILE="$GENERATED_ROOT/vhdl/circuits/tb/tb_${CIRCUIT}.vhd"

WORK_DIR="$PROJECT_ROOT/scripts/simulation/work/$CIRCUIT"



CAMPAIGN_ROOT="$PROJECT_ROOT/results/$CAMPAIGN_NAME"

VCD_ROOT="$CAMPAIGN_ROOT/vcd"
ACTIVITY_ROOT="$CAMPAIGN_ROOT/activity"
COMPARISON_ROOT="$CAMPAIGN_ROOT/comparisons"
SUMMARY_ROOT="$CAMPAIGN_ROOT/summary"

VCD_CIRCUIT_ROOT="$VCD_ROOT/$CIRCUIT"
ACTIVITY_CIRCUIT_ROOT="$ACTIVITY_ROOT/$CIRCUIT"
COMPARISON_CIRCUIT_ROOT="$COMPARISON_ROOT/$CIRCUIT"
SUMMARY_CIRCUIT_ROOT="$SUMMARY_ROOT/$CIRCUIT"

INPUTS_FILE="$PROJECT_ROOT/data/inputs/inputs_${CIRCUIT}.txt"
OUTPUTS_FILE="$PROJECT_ROOT/data/outputs/outputs_${CIRCUIT}.txt"

SUMMARY_FILE="$SUMMARY_CIRCUIT_ROOT/${CIRCUIT}_by_margin.csv"

export PROJECT_ROOT
export CIRCUIT
export VERILOG_FILE
export DELAY_FILE
export MARGINS
export NUMBER_OF_RUNS
export NB_VECTORS
export NB_CYCLES
export STEP_TIME_NS
export STIMULUS_SEED
export DEBUG_INTERNAL_SIGNALS
export OUTPUTS_ONLY
export CAMPAIGN_NAME

export VCD_ROOT
export INPUTS_FILE
export OUTPUTS_FILE


if (( NUMBER_OF_RUNS <= 0 )); then
    echo "[ERROR] NUMBER_OF_RUNS must be greater than zero."
    exit 1
fi

if (( NB_VECTORS <= 0 )); then
    echo "[ERROR] NB_VECTORS must be greater than zero."
    exit 1
fi

for required_file in \
    "$VERILOG_FILE" \
    "$DELAY_FILE" \
    "$GENERATOR" \
    "$SIMULATOR" \
    "$ANALYZER" \
    "$COMPARATOR" \
    "$SUMMARIZER"
do
    if [ ! -f "$required_file" ]; then
        echo "[ERROR] Required file not found:"
        echo "        $required_file"
        exit 1
    fi
done

IFS=',' read -r -a margin_values <<< "$MARGINS"

expected_varied_runs=$((
    ${#margin_values[@]} * NUMBER_OF_RUNS
))

expected_vcd_count=$((1 + expected_varied_runs))
expected_comparison_count=$expected_varied_runs


echo "=================================================="
echo "Healthy delay-variation campaign"
echo "=================================================="
echo
echo "Campaign             : $CAMPAIGN_NAME"
echo "Circuit              : $CIRCUIT"
echo "Netlist              : $VERILOG_FILE"
echo "Delay model          : $DELAY_FILE"
echo "Margins              : $MARGINS"
echo "Runs per margin      : $NUMBER_OF_RUNS"
echo "Vectors              : $NB_VECTORS"
echo "Analysis cycles      : $NB_CYCLES"
echo "Step time            : $STEP_TIME_NS ns"
echo "Stimulus seed        : $STIMULUS_SEED"
echo "Internal signals     : $DEBUG_INTERNAL_SIGNALS"
echo "Outputs only         : $OUTPUTS_ONLY"
echo "Expected VCD files   : $expected_vcd_count"
echo "Expected comparisons : $expected_comparison_count"
echo


# Nettoyage


echo "[+] Cleaning previous results for this campaign..."

rm -rf "$VHDL_DIR"
rm -rf "$DELAY_REPORT_DIR"
rm -rf "$WORK_DIR"

rm -rf "$VCD_CIRCUIT_ROOT"
rm -rf "$ACTIVITY_CIRCUIT_ROOT"
rm -rf "$COMPARISON_CIRCUIT_ROOT"
rm -rf "$SUMMARY_CIRCUIT_ROOT"

rm -f "$TB_FILE"
rm -f "$INPUTS_FILE"
rm -f "$OUTPUTS_FILE"

mkdir -p "$VCD_CIRCUIT_ROOT"
mkdir -p "$ACTIVITY_CIRCUIT_ROOT"
mkdir -p "$COMPARISON_CIRCUIT_ROOT"
mkdir -p "$SUMMARY_CIRCUIT_ROOT"


# Étape 1 : génération VHDL


echo
echo "[1/5] Generating the nominal and varied VHDL circuits..."

ruby "$GENERATOR"

if [ ! -d "$VHDL_DIR" ]; then
    echo "[ERROR] VHDL circuits were not generated:"
    echo "        $VHDL_DIR"
    exit 1
fi

if [ ! -s "$TB_FILE" ]; then
    echo "[ERROR] Testbench was not generated:"
    echo "        $TB_FILE"
    exit 1
fi

if [ ! -s "$INPUTS_FILE" ]; then
    echo "[ERROR] Input list was not generated:"
    echo "        $INPUTS_FILE"
    exit 1
fi

if [ "$OUTPUTS_ONLY" = "true" ] && [ ! -s "$OUTPUTS_FILE" ]; then
    echo "[ERROR] Output list was not generated:"
    echo "        $OUTPUTS_FILE"
    exit 1
fi

# Étape 2 : simulations


echo
echo "[2/5] Running GHDL simulations..."

bash "$SIMULATOR"

vcd_files=(
    "$VCD_CIRCUIT_ROOT"/margin_*/*.vcd
)

if [ "${#vcd_files[@]}" -eq 0 ]; then
    echo "[ERROR] No VCD file found in:"
    echo "        $VCD_CIRCUIT_ROOT"
    exit 1
fi

if [ "${#vcd_files[@]}" -ne "$expected_vcd_count" ]; then
    echo "[ERROR] Unexpected number of VCD files."
    echo "        Expected: $expected_vcd_count"
    echo "        Found   : ${#vcd_files[@]}"
    exit 1
fi

echo "[+] VCD files generated: ${#vcd_files[@]}"


# Étape 3 : extraction de l’activité


echo
echo "[3/5] Extracting transient activity from VCD files..."

analysis_count=0

for vcd_file in "${vcd_files[@]}"; do
    run_name="$(basename "$vcd_file" .vcd)"
    margin_name="$(basename "$(dirname "$vcd_file")")"

    activity_dir="$ACTIVITY_CIRCUIT_ROOT/$margin_name"
    activity_file="$activity_dir/${run_name}.csv"

    mkdir -p "$activity_dir"

    echo "    Analyzing: $margin_name/$run_name"

    NB_CYCLES="$NB_CYCLES" \
    STEP_TIME_NS="$STEP_TIME_NS" \
    INPUTS_FILE="$INPUTS_FILE" \
    OUTPUTS_FILE="$OUTPUTS_FILE" \
    OUTPUTS_ONLY="$OUTPUTS_ONLY" \
    ruby "$ANALYZER" \
        "$vcd_file" \
        "$activity_file"

    if [ ! -s "$activity_file" ]; then
        echo "[ERROR] Activity CSV was not generated:"
        echo "        $activity_file"
        exit 1
    fi

    analysis_count=$((analysis_count + 1))
done


# Étape 4 : comparaison à la référence nominale
echo
echo "[4/5] Comparing varied runs with the nominal reference..."

REFERENCE_RUN="${CIRCUIT}_margin_00_run_001"

reference_file="$ACTIVITY_CIRCUIT_ROOT/margin_00/"\
"${REFERENCE_RUN}.csv"

if [ ! -s "$reference_file" ]; then
    echo "[ERROR] Nominal activity reference was not found:"
    echo "        $reference_file"
    exit 1
fi

activity_files=(
    "$ACTIVITY_CIRCUIT_ROOT"/margin_*/*.csv
)

comparison_count=0

for activity_file in "${activity_files[@]}"; do
    if [ "$activity_file" = "$reference_file" ]; then
        continue
    fi

    run_name="$(basename "$activity_file" .csv)"
    margin_name="$(basename "$(dirname "$activity_file")")"

    # On ne compare pas d'autres références nominales éventuelles.
    if [ "$margin_name" = "margin_00" ]; then
        continue
    fi

    comparison_dir="$COMPARISON_CIRCUIT_ROOT/$margin_name"

    comparison_file="$comparison_dir/"\
"${run_name}_vs_reference.txt"

    mkdir -p "$comparison_dir"

    echo "    Comparing: $run_name"

    NB_CYCLES="$NB_CYCLES" \
    STEP_TIME_NS="$STEP_TIME_NS" \
    ruby "$COMPARATOR" \
        "$reference_file" \
        "$activity_file" \
        > "$comparison_file"

    if [ ! -s "$comparison_file" ]; then
        echo "[ERROR] Comparison report was not generated:"
        echo "        $comparison_file"
        exit 1
    fi

    comparison_count=$((comparison_count + 1))
done

if [ "$comparison_count" -ne "$expected_comparison_count" ]; then
    echo "[ERROR] Unexpected number of comparison reports."
    echo "        Expected: $expected_comparison_count"
    echo "        Found   : $comparison_count"
    exit 1
fi


# Étape 5 : résumé statistique


echo
echo "[5/5] Summarizing variation effects by margin..."

ruby "$SUMMARIZER" \
    "$COMPARISON_CIRCUIT_ROOT" \
    "$SUMMARY_FILE"

if [ ! -s "$SUMMARY_FILE" ]; then
    echo "[ERROR] Summary was not generated:"
    echo "        $SUMMARY_FILE"
    exit 1
fi


echo
echo "=================================================="
echo "Campaign completed successfully"
echo "=================================================="
echo
echo "Circuit              : $CIRCUIT"
echo "VCD files analyzed   : $analysis_count"
echo "Comparisons produced : $comparison_count"
echo
echo "VCD files:"
echo "  $VCD_CIRCUIT_ROOT"
echo
echo "Activity files:"
echo "  $ACTIVITY_CIRCUIT_ROOT"
echo
echo "Comparison reports:"
echo "  $COMPARISON_CIRCUIT_ROOT"
echo
echo "Summary:"
echo "  $SUMMARY_FILE"