#!/usr/bin/env bash
# Sao chep nguyen thu muc 191 package nhieu version cua Tien, khong chay code.
set -Eeuo pipefail

if (( $# < 1 || $# > 3 )); then
  echo "SU DUNG: $0 /duong/dan/den/multi_version [thu_muc_dich] [thu_muc_goc_de_tim_package_info]" >&2
  echo "Vi du: $0 /home/kali/Dataset-all-package/Dataset-Tong-hop/multi_version /home/kali/Tien_Dataset /home/kali/Dataset-all-package" >&2
  exit 2
fi

for cmd in realpath rsync zip find; do
  command -v "$cmd" >/dev/null || { echo "Thieu lenh: $cmd" >&2; exit 3; }
done

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/danh_sach_191_package_Tien.txt"
[[ -f "$LIST" ]] || { echo "Khong tim thay: $LIST" >&2; exit 3; }
SRC="$(realpath "$1")"
DEST="$(realpath -m "${2:-$HOME/Tien_Dataset}")"
[[ -d "$SRC" ]] || { echo "Khong tim thay thu muc multi_version: $SRC" >&2; exit 3; }
[[ "$SRC" != "$DEST" && "$DEST" != "$SRC"/* ]] || { echo "Thu muc dich khong duoc nam trong thu muc nguon." >&2; exit 3; }

mkdir -p "$DEST/packages"
: > "$DEST/bao_cao_thieu_package.txt"
: > "$DEST/bao_cao_da_sao_chep.txt"
declare -A wanted=()
mapfile -t pkgs < "$LIST"
for pkg in "${pkgs[@]}"; do
  pkg="${pkg%$'\r'}"
  [[ -n "$pkg" ]] || continue
  [[ "$pkg" =~ ^[[:alnum:]_.-]+$ && "$pkg" != .* && "$pkg" != *..* ]] || {
    echo "Ten package khong hop le: $pkg" >&2
    exit 4
  }
  key="${pkg//_/-}"; key="${key,,}"
  wanted["$key"]="$pkg"
  if [[ -d "$SRC/$pkg" ]]; then
    mkdir -p "$DEST/packages/$pkg"
    rsync -a -- "$SRC/$pkg/" "$DEST/packages/$pkg/"
    echo "$pkg" >> "$DEST/bao_cao_da_sao_chep.txt"
    echo "OK: $pkg"
  else
    echo "$pkg" >> "$DEST/bao_cao_thieu_package.txt"
    echo "THIEU: $pkg"
  fi
done

# Tuy chon: tim cac tep package_info-<ten>.json/ package_info.json nam o ngoai thu muc package.
if (( $# == 3 )); then
  META_ROOT="$(realpath "$3")"
  [[ -d "$META_ROOT" ]] || { echo "Khong tim thay thu muc metadata: $META_ROOT" >&2; exit 3; }
  [[ "$DEST" != "$META_ROOT" && "$DEST" != "$META_ROOT"/* ]] || {
    echo "De tranh lap vo han, thu muc dich phai nam NGOAI goc metadata." >&2
    exit 3
  }
  echo "Quet package_info bo sung trong: $META_ROOT"
  while IFS= read -r -d '' f; do
    fname="${f##*/}"
    if [[ "$fname" == package_info-*.json ]]; then
      stem="${fname#package_info-}"; stem="${stem%.json}"
    elif [[ "$fname" == package_info.json ]]; then
      stem="$(basename "$(dirname "$f")")"
    else
      continue
    fi
    key="${stem//_/-}"; key="${key,,}"
    if [[ -n "${wanted[$key]+x}" ]]; then
      pkg="${wanted[$key]}"
      # Giu duong dan goc trong thu muc __metadata_bo_sung.
      rel="${f#"$META_ROOT"/}"
      target="$DEST/packages/$pkg/__metadata_bo_sung/$rel"
      mkdir -p "$(dirname "$target")"
      cp -a -- "$f" "$target"
    fi
  done < <(find "$META_ROOT" -type f -name 'package_info*.json' -print0)
fi

# 10 package/ZIP, theo thu tu trong Excel. ZIP khong can giai nen tar/wheel.
for (( start=0; start<${#pkgs[@]}; start+=10 )); do
  paths=()
  last=$((start+10))
  (( last > ${#pkgs[@]} )) && last=${#pkgs[@]}
  for (( i=start; i<last; i++ )); do
    pkg="${pkgs[i]%$'\r'}"
    [[ -d "$DEST/packages/$pkg" ]] && paths+=("packages/$pkg")
  done
  if (( ${#paths[@]} )); then
    outfile="$DEST/Tien_$(printf '%03d' "$((start+1))")_$(printf '%03d' "$last").zip"
    (cd "$DEST" && zip -y -0 -q -r "$outfile" "${paths[@]}")
    echo "TAO ZIP: $outfile"
  fi
done

echo
printf 'Da sao chep: %s/191 package\n' "$(wc -l < "$DEST/bao_cao_da_sao_chep.txt")"
printf 'Thieu: %s package (xem bao_cao_thieu_package.txt)\n' "$(wc -l < "$DEST/bao_cao_thieu_package.txt")"
echo "Thu muc dich: $DEST"
echo "ZIP theo dot: $DEST/Tien_*.zip"
