#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

CIRCUIT="${CIRCUIT:-c432}"
CAMPAIGN_NAME="${CAMPAIGN_NAME:-trojan_campaign}"


VARIANTS="${VARIANTS:-clean trojan}"
read -r -a variants <<< "$VARIANTS"

if [[ ${#variants[@]} -eq 0 ]]; then
  echo "[ERROR] Aucune variante sélectionnée" >&2
  exit 1
fi

for variant in "${variants[@]}"; do
  case "$variant" in
    clean|trojan) ;;
    *)
      echo "[ERROR] Variante inconnue : $variant" >&2
      exit 1
      ;;
  esac
done

CIRCUIT_ROOT="$PROJECT_ROOT/build/vhdl/paired"
WORK_ROOT="$PROJECT_ROOT/build/simulation/work/paired"

TB_FILE="$PROJECT_ROOT/build/vhdl/circuits/tb/tb_${CIRCUIT}.vhd"
TB_ENTITY="tb_${CIRCUIT}"


VCD_ROOT="${VCD_ROOT:-$PROJECT_ROOT/results/vcd}"
VCD_CAMPAIGN_ROOT="$VCD_ROOT/$CIRCUIT/$CAMPAIGN_NAME"

if [[ ! -s "$TB_FILE" ]]; then
  echo "[ERROR] Testbench absent ou vide : $TB_FILE" >&2
  exit 1
fi

simulation_count=0

for variant in "${variants[@]}"; do
  circuit_files=(
    "$CIRCUIT_ROOT/$variant"/margin_*/*.vhd
  )

  if [[ ${#circuit_files[@]} -eq 0 ]]; then
    echo "[ERROR] Aucun VHDL pour $variant" >&2
    exit 1
  fi

  for circuit_file in "${circuit_files[@]}"; do
    run_name="$(basename "$circuit_file" .vhd)"
    margin_name="$(basename "$(dirname "$circuit_file")")"

    work_dir="$WORK_ROOT/$CIRCUIT/$variant/$margin_name/$run_name"
    vcd_dir="$VCD_CAMPAIGN_ROOT/$variant/$margin_name"
    vcd_file="$vcd_dir/$run_name.vcd"


    rm -rf -- "$work_dir"
    mkdir -p "$work_dir" "$vcd_dir"

    echo "[+] Simulation : $variant/$margin_name/$run_name"

    ghdl -a \
      --std=08 \
      --workdir="$work_dir" \
      "$circuit_file"

    ghdl -a \
      --std=08 \
      --workdir="$work_dir" \
      "$TB_FILE"

    ghdl -e \
      --std=08 \
      --workdir="$work_dir" \
      "$TB_ENTITY"

    ghdl -r \
      --std=08 \
      --workdir="$work_dir" \
      "$TB_ENTITY" \
      --vcd="$vcd_file"

    if [[ ! -s "$vcd_file" ]]; then
      echo "[ERROR] VCD absent ou vide : $vcd_file" >&2
      exit 1
    fi

    simulation_count=$((simulation_count + 1))
  done
done

echo "Simulations terminées : $simulation_count"
echo "VCD : $VCD_CAMPAIGN_ROOT"