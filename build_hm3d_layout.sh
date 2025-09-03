#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
# Root where your extracted HM3D folders live (edit if needed)
SRC_ROOT="${1:-$PWD}"

# Destination root (the unified layout you want)
DEST_ROOT="${2:-$PWD/hm3d}"

# Source directories (edit names here if your folder names differ)
MINI_HAB="${SRC_ROOT}/hm3d-minival-habitat-v0.2"
MINI_SEM="${SRC_ROOT}/hm3d-minival-semantic-annots-v0.2"
MINI_GLB="${SRC_ROOT}/hm3d-minival-glb-v0.2"              # optional

TRAIN_HAB="${SRC_ROOT}/hm3d-train-habitat-v0.2"
TRAIN_SEM="${SRC_ROOT}/hm3d-train-semantic-annots-v0.2"   # optional
TRAIN_GLB="${SRC_ROOT}/hm3d-train-glb-v0.2"               # optional

VAL_HAB="${SRC_ROOT}/hm3d-val-habitat-v0.2"
VAL_SEM="${SRC_ROOT}/hm3d-val-semantic-annots-v0.2"   # optional
VAL_GLB="${SRC_ROOT}/hm3d-val-glb-v0.2"               # optional

CONF_DIR="${SRC_ROOT}/hm3d-minival-semantic-configs-v0.2" # contains config json
CONF_FILE="hm3d_annotated_basis.scene_dataset_config.json"

# Link vs copy for large assets (symlink keeps disk usage low)
COPY_MODE="${COPY_MODE:-link}"   # "link" or "copy"

# === HELPERS ===
ln_or_cp () {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || return 0
  if [[ "$COPY_MODE" == "copy" ]]; then
    cp -n "$src" "$dst"
  else
    ln -sfn "$src" "$dst"
  fi
}

process_split () {
  local SPLIT_NAME="$1"    # "val" (minival) or "train"
  local HAB_DIR="$2"       # *-habitat-v0.2
  local SEM_DIR="$3"       # *-semantic-annots-v0.2 (may not exist)
  local GLB_DIR="$4"       # *-glb-v0.2 (may not exist)

  [[ -d "$HAB_DIR" ]] || { echo "Skip $SPLIT_NAME: $HAB_DIR not found."; return 0; }

  echo "==> Processing split: $SPLIT_NAME"
  mkdir -p "${DEST_ROOT}/${SPLIT_NAME}"

  # Each scene is a directory named like 00824-Dd4bFSTQ8gi under HAB_DIR
  find "$HAB_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r SCENE_DIR; do
    SCENE_BASENAME="$(basename "$SCENE_DIR")"             # e.g., 00824-Dd4bFSTQ8gi
    SCENE_ID="${SCENE_BASENAME#*-}"                       # e.g., Dd4bFSTQ8gi

    OUT_DIR="${DEST_ROOT}/${SPLIT_NAME}/${SCENE_BASENAME}"
    mkdir -p "$OUT_DIR"

    # habitat (basis) files live directly inside SCENE_DIR, named by SCENE_ID
    ln_or_cp "${SCENE_DIR}/${SCENE_ID}.basis.glb"     "${OUT_DIR}/${SCENE_ID}.basis.glb"
    ln_or_cp "${SCENE_DIR}/${SCENE_ID}.basis.navmesh" "${OUT_DIR}/${SCENE_ID}.basis.navmesh"

    # optional plain .glb (if you downloaded/extracted the *-glb-v0.2 package)
    if [[ -d "$GLB_DIR/${SCENE_BASENAME}" ]]; then
      ln_or_cp "${GLB_DIR}/${SCENE_BASENAME}/${SCENE_ID}.glb" "${OUT_DIR}/${SCENE_ID}.glb"
    fi

    # optional semantic annots
    if [[ -d "$SEM_DIR/${SCENE_BASENAME}" ]]; then
      ln_or_cp "${SEM_DIR}/${SCENE_BASENAME}/${SCENE_ID}.semantic.glb" "${OUT_DIR}/${SCENE_ID}.semantic.glb"
      ln_or_cp "${SEM_DIR}/${SCENE_BASENAME}/${SCENE_ID}.semantic.txt" "${OUT_DIR}/${SCENE_ID}.semantic.txt"
    fi

    # sanity: warn if key files missing
    for f in "${SCENE_ID}.basis.glb" "${SCENE_ID}.basis.navmesh"; do
      [[ -e "${OUT_DIR}/${f}" ]] || echo "WARN [$SPLIT_NAME/$SCENE_BASENAME]: missing ${f}"
    done
  done
}

# === RUN ===
mkdir -p "$DEST_ROOT"

# Copy/link config JSON to top-level
if [[ -f "${CONF_DIR}/${CONF_FILE}" ]]; then
  ln_or_cp "${CONF_DIR}/${CONF_FILE}" "${DEST_ROOT}/${CONF_FILE}"
else
  echo "WARN: ${CONF_FILE} not found under ${CONF_DIR}"
fi

# Build val (minival) and train splits
process_split "minival"   "$MINI_HAB"  "$MINI_SEM"   "$MINI_GLB"
process_split "train" "$TRAIN_HAB" "$TRAIN_SEM" "$TRAIN_GLB"
process_split "val"   "$VAL_HAB"  "$VAL_SEM" "$VAL_GLB"

# Optional: write a quick tree to help verify
if command -v tree >/dev/null 2>&1; then
  tree -L 3 -h "${DEST_ROOT}" > "${DEST_ROOT}/tree_structure.txt"
  echo "Wrote ${DEST_ROOT}/tree_structure.txt"
else
  echo "Tip: install 'tree' to dump a pretty listing (e.g., sudo apt-get install tree)"
fi

echo "Done. Unified layout at: ${DEST_ROOT}"
