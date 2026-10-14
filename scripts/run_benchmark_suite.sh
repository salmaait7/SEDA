#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/home/salma/SEDA}"
RUNNER="$PROJECT_ROOT/scripts/run_variation.sh"

CIRCUITS="${CIRCUITS:-c6288}"
DELAY_MODELS="${DELAY_MODELS:-simplified,liberty}"

MARGINS="${MARGINS:-0.05,0.10,0.15,0.20}"
NUMBER_OF_RUNS="${NUMBER_OF_RUNS:-30}"
NB_VECTORS="${NB_VECTORS:-500}"
NB_CYCLES="${NB_CYCLES:-$NB_VECTORS}"
STEP_TIME_NS="${STEP_TIME_NS:-40.0}"
STIMULUS_SEED="${STIMULUS_SEED:-42}"

if [[ ! -f "$RUNNER" ]]; then
    echo "[ERROR] Campaign runner not found:"
    echo "        $RUNNER"
    exit 1
fi

IFS=',' read -r -a circuit_list <<< "$CIRCUITS"
IFS=',' read -r -a delay_model_list <<< "$DELAY_MODELS"

completed=0
failed=0

for delay_model in "${delay_model_list[@]}"; do
    case "$delay_model" in
        simplified)
            delay_file="$PROJECT_ROOT/config/delay_models/gate_delays_simplified.json"
            ;;
        liberty)
            delay_file="$PROJECT_ROOT/config/delay_models/gate_delays.json"
            ;;
        *)
            echo "[ERROR] Unknown delay model: $delay_model"
            exit 1
            ;;
    esac

    if [[ ! -f "$delay_file" ]]; then
        echo "[ERROR] Delay file not found:"
        echo "        $delay_file"
        exit 1
    fi

    for circuit in "${circuit_list[@]}"; do
        verilog_file="$PROJECT_ROOT/data/benchmarks/clean/${circuit}.v"
        campaign_name="healthy_variation_${delay_model}_500v_v1"

        echo
        echo "=================================================="
        echo "Running benchmark campaign"
        echo "=================================================="
        echo "Circuit      : $circuit"
        echo "Delay model  : $delay_model"
        echo "Delay file   : $delay_file"
        echo "Campaign     : $campaign_name"
        echo

        if [[ ! -f "$verilog_file" ]]; then
            echo "[ERROR] Netlist not found: $verilog_file"
            failed=$((failed + 1))
            continue
        fi

        if PROJECT_ROOT="$PROJECT_ROOT" \
           CIRCUIT="$circuit" \
           VERILOG_FILE="$verilog_file" \
           DELAY_FILE="$delay_file" \
           CAMPAIGN_NAME="$campaign_name" \
           MARGINS="$MARGINS" \
           NUMBER_OF_RUNS="$NUMBER_OF_RUNS" \
           NB_VECTORS="$NB_VECTORS" \
           NB_CYCLES="$NB_CYCLES" \
           STEP_TIME_NS="$STEP_TIME_NS" \
           STIMULUS_SEED="$STIMULUS_SEED" \
           bash "$RUNNER"
        then
            completed=$((completed + 1))
        else
            echo "[ERROR] Campaign failed: $delay_model / $circuit"
            failed=$((failed + 1))
        fi
    done
done

echo
echo "=================================================="
echo "Benchmark suite completed"
echo "=================================================="
echo "Successful campaigns : $completed"
echo "Failed campaigns     : $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi