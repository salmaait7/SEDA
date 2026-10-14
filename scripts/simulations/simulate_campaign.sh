#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob


SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="${PROJECT_ROOT:-$(
    cd "$SCRIPT_DIR/../.."
    pwd
)}"

cd "$PROJECT_ROOT"


CIRCUIT="${CIRCUIT:-}"

CIRCUIT_DIR="${CIRCUIT_DIR:-\
$PROJECT_ROOT/build/vhdl/circuits/$CIRCUIT}"

TB_DIR="${TB_DIR:-\
$PROJECT_ROOT/build/vhdl/circuits/tb}"

WORK_ROOT="${WORK_ROOT:-\
$PROJECT_ROOT/build/simulation/work}"


VCD_ROOT="${VCD_ROOT:-\
$PROJECT_ROOT/build/results/vcd}"

GHDL_STD="${GHDL_STD:-08}"

mkdir -p "$WORK_ROOT"
mkdir -p "$VCD_ROOT"


if ! command -v ghdl >/dev/null 2>&1; then
    echo "[ERROR] GHDL is not installed or not available in PATH."
    exit 1
fi


circuit_files=(
    "$CIRCUIT_DIR"/margin_*/*.vhd
)

if [ "${#circuit_files[@]}" -eq 0 ]; then
    echo "[ERROR] No generated VHDL circuit found in:"
    echo "        $CIRCUIT_DIR"
    exit 1
fi

echo
echo "=================================================="
echo "GHDL simulations"
echo "=================================================="
echo
echo "Requested circuit : ${CIRCUIT:-all}"
echo "Circuit directory : $CIRCUIT_DIR"
echo "Testbench directory: $TB_DIR"
echo "Work directory    : $WORK_ROOT"
echo "VCD root          : $VCD_ROOT"
echo "GHDL standard     : $GHDL_STD"
echo



simulation_count=0

for circuit_file in "${circuit_files[@]}"; do
    circuit_filename="$(basename "$circuit_file")"
    run_name="${circuit_filename%.vhd}"

    circuit_name="${run_name%%_margin_*}"

    if [ -n "$CIRCUIT" ] &&
       [ "$circuit_name" != "$CIRCUIT" ]; then
        continue
    fi

    margin_name="$(basename "$(dirname "$circuit_file")")"

    tb_file="$TB_DIR/tb_${circuit_name}.vhd"
    tb_entity="tb_${circuit_name}"

    if [ ! -f "$tb_file" ]; then
        echo "[ERROR] Testbench not found:"
        echo "        $tb_file"
        exit 1
    fi

    run_work_dir="$WORK_ROOT/$circuit_name/$margin_name/$run_name"

    vcd_dir="$VCD_ROOT/$circuit_name/$margin_name"
    vcd_file="$vcd_dir/${run_name}.vcd"

    mkdir -p "$run_work_dir"
    mkdir -p "$vcd_dir"

    echo "[+] Simulating: $run_name"
    echo "    Circuit : $circuit_name"
    echo "    Margin  : $margin_name"

  
    ghdl -a \
        --std="$GHDL_STD" \
        --workdir="$run_work_dir" \
        "$circuit_file"


    ghdl -a \
        --std="$GHDL_STD" \
        --workdir="$run_work_dir" \
        "$tb_file"


    ghdl -e \
        --std="$GHDL_STD" \
        --workdir="$run_work_dir" \
        "$tb_entity"


    ghdl -r \
        --std="$GHDL_STD" \
        --workdir="$run_work_dir" \
        "$tb_entity" \
        --vcd="$vcd_file"

    if [ ! -s "$vcd_file" ]; then
        echo "[ERROR] VCD file was not generated:"
        echo "        $vcd_file"
        exit 1
    fi

    echo "    VCD     : $vcd_file"
    echo

    simulation_count=$((simulation_count + 1))
done


# Vérification finale


if [ "$simulation_count" -eq 0 ]; then
    echo "[ERROR] No simulation was executed."

    if [ -n "$CIRCUIT" ]; then
        echo "        Requested circuit: $CIRCUIT"
    fi

    exit 1
fi

echo "=================================================="
echo "Simulations completed successfully"
echo "=================================================="
echo
echo "Simulations : $simulation_count"
echo "VCD root    : $VCD_ROOT"