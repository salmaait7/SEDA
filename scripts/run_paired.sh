#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Circuit et campagne
CIRCUIT="${CIRCUIT:-c432}"
CAMPAIGN_NAME="${CAMPAIGN_NAME:-trojan_campaign}"

# Variantes à simuler et à analyser
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

# Fichiers d'entrée
CLEAN_VERILOG_FILE="${CLEAN_VERILOG_FILE:-$PROJECT_ROOT/data/benchmarks/clean/${CIRCUIT}.v}"
TROJAN_VERILOG_FILE="${TROJAN_VERILOG_FILE:-$PROJECT_ROOT/data/benchmarks/trojan/${CIRCUIT}_alt2.v}"
DELAY_FILE="${DELAY_FILE:-$PROJECT_ROOT/config/delay_models/gate_delays.json}"

# Paramètres de simulation
MARGINS="${MARGINS:-0.05,0.10,0.15,0.20}"
NUMBER_OF_RUNS="${NUMBER_OF_RUNS:-30}"
START_RUN="${START_RUN:-1}"
NB_VECTORS="${NB_VECTORS:-100}"
NB_CYCLES="${NB_CYCLES:-$NB_VECTORS}"
STEP_TIME_NS="${STEP_TIME_NS:-40.0}"
STIMULUS_SEED="${STIMULUS_SEED:-42}"

# Scripts
GENERATOR="$PROJECT_ROOT/scripts/campaigns/generate_paired_campaign.rb"
SIMULATOR="$PROJECT_ROOT/scripts/simulations/sim_paired.sh"
ANALYZER="$PROJECT_ROOT/scripts/analysis/analyze_vcd.rb"

# Dossiers des résultats
CAMPAIGN_ROOT="$PROJECT_ROOT/results/local_detector/$CIRCUIT/$CAMPAIGN_NAME"

ACTIVITY_ROOT="${ACTIVITY_ROOT:-$CAMPAIGN_ROOT/activity}"
CLEAN_ROOT="$ACTIVITY_ROOT/clean"
TROJAN_ROOT="$ACTIVITY_ROOT/trojan"

# Le simulateur ajoute CIRCUIT/CAMPAIGN_NAME à VCD_ROOT
VCD_ROOT="$CAMPAIGN_ROOT/vcd"
VCD_CAMPAIGN_ROOT="$VCD_ROOT/$CIRCUIT/$CAMPAIGN_NAME"

# Fichiers de travail
PAIRED_VHDL_DIR="$PROJECT_ROOT/build/vhdl/paired"
PAIRED_DELAY_DIR="$PROJECT_ROOT/build/delays/paired"
PAIRED_WORK_DIR="$PROJECT_ROOT/build/simulation/work/paired/$CIRCUIT"

TB_FILE="$PROJECT_ROOT/build/vhdl/circuits/tb/tb_${CIRCUIT}.vhd"
INPUTS_FILE="$PROJECT_ROOT/data/inputs/inputs_${CIRCUIT}.txt"
OUTPUTS_FILE="$PROJECT_ROOT/data/outputs/outputs_${CIRCUIT}.txt"

# Vérifier les fichiers nécessaires
for required_file in \
  "$CLEAN_VERILOG_FILE" \
  "$TROJAN_VERILOG_FILE" \
  "$DELAY_FILE" \
  "$GENERATOR" \
  "$SIMULATOR" \
  "$ANALYZER"
do
  if [[ ! -f "$required_file" ]]; then
    echo "[ERROR] Fichier introuvable : $required_file" >&2
    exit 1
  fi
done

# Paramètres transmis aux scripts enfants
export PROJECT_ROOT CIRCUIT CAMPAIGN_NAME VARIANTS
export CLEAN_VERILOG_FILE TROJAN_VERILOG_FILE DELAY_FILE
export MARGINS NUMBER_OF_RUNS NB_VECTORS NB_CYCLES
export STEP_TIME_NS STIMULUS_SEED
export VCD_ROOT INPUTS_FILE OUTPUTS_FILE
export ACTIVITY_ROOT CLEAN_ROOT TROJAN_ROOT

cd "$PROJECT_ROOT"

# Nettoyer les fichiers de travail générés
rm -rf -- \
  "$PAIRED_VHDL_DIR" \
  "$PAIRED_DELAY_DIR" \
  "$PAIRED_WORK_DIR"

rm -f -- "$TB_FILE" "$INPUTS_FILE" "$OUTPUTS_FILE"

# Nettoyer et créer uniquement les variantes sélectionnées
for variant in "${variants[@]}"; do
  rm -rf -- \
    "$VCD_CAMPAIGN_ROOT/$variant" \
    "$ACTIVITY_ROOT/$variant"

  mkdir -p \
    "$VCD_CAMPAIGN_ROOT/$variant" \
    "$ACTIVITY_ROOT/$variant"
done

echo "Circuit   : $CIRCUIT"
echo "Campagne  : $CAMPAIGN_NAME"
echo "Variantes : $VARIANTS"
echo

# 1. Génération des deux VHDL et vérification de l'appariement
echo "[1/3] Génération des circuits et du testbench..."
ruby "$GENERATOR"

for generated_file in "$TB_FILE" "$INPUTS_FILE" "$OUTPUTS_FILE"; do
  if [[ ! -s "$generated_file" ]]; then
    echo "[ERROR] Fichier non généré ou vide : $generated_file" >&2
    exit 1
  fi
done

# 2. Simulation des variantes sélectionnées
echo
echo "[2/3] Simulation : $VARIANTS..."
bash "$SIMULATOR"

# Récupérer uniquement les VCD des variantes sélectionnées
vcd_files=()

for variant in "${variants[@]}"; do
  variant_files=(
    "$VCD_CAMPAIGN_ROOT/$variant"/margin_*/*.vcd
  )

  if [[ ${#variant_files[@]} -eq 0 ]]; then
    echo "[ERROR] Aucun VCD trouvé pour $variant" >&2
    exit 1
  fi

  vcd_files+=("${variant_files[@]}")
done

# 3. Extraction des activités des sorties
echo
echo "[3/3] Extraction des activités..."

for vcd_file in "${vcd_files[@]}"; do
  run_name="$(basename "$vcd_file" .vcd)"
  margin_name="$(basename "$(dirname "$vcd_file")")"
  variant="$(basename "$(dirname "$(dirname "$vcd_file")")")"

  activity_dir="$ACTIVITY_ROOT/$variant/$margin_name"
  activity_file="$activity_dir/$run_name.csv"

  mkdir -p "$activity_dir"

  echo "  $variant/$margin_name/$run_name"

  OUTPUTS_ONLY=true ruby "$ANALYZER" \
    "$vcd_file" \
    "$activity_file"

  if [[ ! -s "$activity_file" ]]; then
    echo "[ERROR] CSV non généré ou vide : $activity_file" >&2
    exit 1
  fi
done

echo
echo "Extraction terminée : ${#vcd_files[@]} fichiers."
echo "Activités : $ACTIVITY_ROOT"
echo "VCD       : $VCD_CAMPAIGN_ROOT"