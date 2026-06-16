#! /bin/bash
PROJECT_ROOT="/home/salma/SEDA"
CIRCUIT_DIR="$PROJECT_ROOT/generated/vhdl/circuits"
TB_DIR="$PROJECT_ROOT/generated/vhdl/tb"
WORK_DIR="$PROJECT_ROOT/simuation/work"

echo "[+] Cleaning previous work files..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "[+] Analyzing circuit files..."
echo "==============================="
for file in $CIRCUIT_DIR/*.vhd; do
    filename="$(basename "$file")"
    echo "analyzing $filename"
    ghdl -a --workdir="$WORK_DIR" "$file"
done

echo "[+] Analyzing testbench files..."
echo "===================================="
for file in $TB_DIR/tb_*.vhd; do
    filename="$(basename "$file")"
    echo "analyzing $filename"
    ghdl -a --workdir="$WORK_DIR" "$file"
done

echo "[+] Running testbenches..."
echo "===================================="
for file in $TB_DIR/tb_*.vhd; do
    filename="$(basename "$file")"
    entity="${filename%.vhd}"
    echo "running $entity"
    ghdl -r --workdir="$WORK_DIR" "$entity"
done    
echo "[+] All simulations completed."