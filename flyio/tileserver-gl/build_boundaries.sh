#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# build_boundaries.sh — one‑shot generator for Western‑Hemisphere admin
#                       boundaries vector tiles (countries + states/provinces)
#
# Usage:  ./build_boundaries.sh [OUTPUT_MBtiles]
#         ./build_boundaries.sh boundaries.mbtiles
#
# Requirements (all OSS‑licensed):
#   • curl / wget           — file download
#   • unzip                 — extract Natural Earth zips
#   • ogr2ogr / ogrinfo     — GDAL ≥ 3.0 (MIT)
#   • tippecanoe            — Mapbox Tippecanoe (BSD)
#
# The script downloads Natural Earth Admin‑0 & Admin‑1 shapefiles, trims them
# to the Western Hemisphere (‑180…+20 lon, ‑60…+85 lat), adds a stable "code"
# property (ISO‑3166‑1 alpha‑2 for countries, ISO‑3166‑2 for states), and
# encodes a single boundaries.mbtiles file ready for tileserver‑gl or S3.
# N.B. This will not include the Alaskan Aleutian Islands or the Hawaiian Islands.
# -----------------------------------------------------------------------------
set -euo pipefail

# -------- Tool Check ----------------------------------------------------------
function check_tool() {
    local tool=$1
    local install_hint=$2
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ Error: Required tool '$tool' is not installed." >&2
        echo "💡 Installation hint: $install_hint" >&2
        exit 1
    fi
}

# Check for required tools
echo "==> Checking for required tools..." >&2
check_tool "curl" "brew install curl"
check_tool "unzip" "brew install unzip"
check_tool "ogr2ogr" "brew install gdal"
check_tool "ogrinfo" "brew install gdal"
check_tool "tippecanoe" "brew install tippecanoe"

# -------- Parameters ----------------------------------------------------------
OUT_MB=${1:-"boundaries.mbtiles"}
BBOX="-180 -60 20 85"       # Western Hemisphere lon/lat rectangle
TMP=$(mktemp -d)
SRC_DIR=$TMP/src
TRIM_DIR=$TMP/trim
CACHE_DIR="${HOME}/.cache/naturalearth"
CACHE_CULTURAL="${CACHE_DIR}/10m_cultural.zip"
CACHE_PHYSICAL="${CACHE_DIR}/10m_physical.zip"
# Using AWS Open Data Program mirror
CULTURAL_URL="https://naturalearth.s3.amazonaws.com/10m_cultural/10m_cultural.zip"
PHYSICAL_URL="https://naturalearth.s3.amazonaws.com/10m_physical/10m_physical.zip"

mkdir -p "$SRC_DIR" "$TRIM_DIR" "$CACHE_DIR"

# -------- Helpers -------------------------------------------------------------
function grab() {
  local url=$1 dest=$2
  echo "➡  Downloading $(basename "$url")…" >&2
  
  # Try downloading with curl, with retries and proper error handling
  if ! curl -L --fail --retry 3 --retry-delay 5 "$url" -o "$dest"; then
    echo "❌ Error: Failed to download $(basename "$url")" >&2
    echo "💡 Please check your internet connection and try again." >&2
    echo "💡 If the issue persists, you can manually download the file from:" >&2
    echo "💡 https://www.naturalearthdata.com/downloads/10m-cultural-vectors/" >&2
    echo "💡 and place it at: $dest" >&2
    exit 1
  fi
  
  # Verify the file is a valid zip
  if ! unzip -t "$dest" > /dev/null 2>&1; then
    echo "❌ Error: Downloaded file $(basename "$dest") is corrupted" >&2
    echo "💡 Please try running the script again." >&2
    rm -f "$dest"
    exit 1
  fi
}

function extract_zip() {
  local zip=$1 dest=$2
  if ! unzip -q -d "$dest" "$zip"; then
    echo "❌ Error: Failed to extract $(basename "$zip")" >&2
    exit 1
  fi
}

# -------- 1. Fetch Natural Earth shapefiles ----------------------------------
echo "==> Fetching Natural Earth Admin layers" >&2

# Check if we have cached versions
for url in "$CULTURAL_URL" "$PHYSICAL_URL"; do
  cache_file="${CACHE_DIR}/$(basename "$url")"
  if [ -f "$cache_file" ]; then
    echo "ℹ️  Using cached Natural Earth data from $cache_file" >&2
    # Verify the cached file is still valid
    if ! unzip -t "$cache_file" > /dev/null 2>&1; then
      echo "⚠️  Cached file is corrupted, downloading fresh copy..." >&2
      grab "$url" "$cache_file"
    fi
  else
    echo "ℹ️  No cached version found, downloading fresh copy..." >&2
    grab "$url" "$cache_file"
  fi
done

# Extract only the files we need
echo "==> Extracting required shapefiles..." >&2
extract_zip "$CACHE_CULTURAL" "$SRC_DIR"
extract_zip "$CACHE_PHYSICAL" "$SRC_DIR"

# -------- 2. Trim to Western Hemisphere --------------------------------------
echo "==> Trimming to bbox $BBOX" >&2

# Find the specific shapefiles we need
ADM0_SHAPE=$(find "$SRC_DIR" -name "ne_10m_admin_0_countries.shp" -print -quit)
ADM1_SHAPE=$(find "$SRC_DIR" -name "ne_10m_admin_1_states_provinces.shp" -print -quit)
LAKES_SHAPE=$(find "$SRC_DIR" -name "ne_10m_lakes.shp" -print -quit)
RIVERS_SHAPE=$(find "$SRC_DIR" -name "ne_10m_rivers_lake_centerlines.shp" -print -quit)

# Verify we found the required shapefiles
if [ -z "$ADM0_SHAPE" ] || [ -z "$ADM1_SHAPE" ] || [ -z "$LAKES_SHAPE" ] || [ -z "$RIVERS_SHAPE" ]; then
  echo "❌ Error: Could not find required shapefiles in $SRC_DIR" >&2
  echo "💡 Please check if the zip files were extracted correctly." >&2
  exit 1
fi

# Process each shapefile individually
for shp in "$ADM0_SHAPE" "$ADM1_SHAPE" "$LAKES_SHAPE" "$RIVERS_SHAPE"; do
  fname=$(basename "$shp")
  echo "Processing $fname..." >&2
  # Suppress encoding warnings and ensure UTF-8 output
  if ! ogr2ogr -spat $BBOX -lco ENCODING=UTF-8 "$TRIM_DIR/$fname" "$shp" 2>/dev/null; then
    echo "❌ Error: Failed to process $fname" >&2
    exit 1
  fi
done

# -------- 3. Add stable codes and filter states/provinces --------------------
echo "==> Adding stable codes and filtering states/provinces" >&2
ADM1_SHAPE=$(find "$TRIM_DIR" -name "ne_10m_admin_1_states_provinces.shp" -print -quit)

# Verify we found the trimmed shapefile
if [ -z "$ADM1_SHAPE" ]; then
  echo "❌ Error: Could not find trimmed states/provinces shapefile" >&2
  exit 1
fi

# Create a temporary shapefile for the update
TEMP_SHAPE="${ADM1_SHAPE%.shp}_temp.shp"

# For states/provinces, copy existing fields and add code field, filtering to only US, CA, MX, and BR
echo "Creating new shapefile with code field and filtered countries..." >&2
TABLE_NAME=$(basename "${ADM1_SHAPE%.shp}")
if ! ogr2ogr -f "ESRI Shapefile" "$TEMP_SHAPE" "$ADM1_SHAPE" \
  -sql "SELECT *, COALESCE(iso_3166_2, adm1_code) AS code FROM \"$TABLE_NAME\" WHERE adm0_a3 IN ('USA', 'CAN', 'MEX', 'BRA')" \
  -dialect SQLITE; then
  echo "❌ Error: Failed to update state/province codes" >&2
  exit 1
fi

# Replace the original with the updated version
echo "Updating original shapefile..." >&2
for ext in shp dbf shx prj; do
  if [ -f "${TEMP_SHAPE%.*}.$ext" ]; then
    mv "${TEMP_SHAPE%.*}.$ext" "${ADM1_SHAPE%.*}.$ext"
  fi
done

# -------- 4. Encode vector tiles with Tippecanoe -----------------------------
echo "==> Encoding vector tiles ($OUT_MB)…" >&2

# Create a temporary directory for GeoJSON files
GEOJSON_DIR="$TMP/geojson"
mkdir -p "$GEOJSON_DIR"

# Convert shapefiles to GeoJSON and ensure UTF-8 encoding
echo "Converting shapefiles to GeoJSON..." >&2
for shp in "$TRIM_DIR"/*.shp; do
  base=$(basename "$shp" .shp)
  temp_json="$GEOJSON_DIR/${base}_temp.geojson"
  final_json="$GEOJSON_DIR/$base.geojson"
  
  # Convert to GeoJSON
  if ! ogr2ogr -f GeoJSON \
       -preserve_fid \
       "$temp_json" \
       "$shp"; then
    echo "❌ Error: Failed to convert $base to GeoJSON" >&2
    exit 1
  fi
  
  # Ensure UTF-8 encoding
  if ! iconv -f ISO-8859-1 -t UTF-8 "$temp_json" > "$final_json"; then
    echo "❌ Error: Failed to convert encoding for $base" >&2
    exit 1
  fi
  rm "$temp_json"
done

# Find all final GeoJSON files
GEOJSON_FILES=$(find "$GEOJSON_DIR" -name "*.geojson" ! -name "*_temp.geojson" | tr '\n' ' ')

if [ -z "$GEOJSON_FILES" ]; then
  echo "❌ Error: No GeoJSON files found in $GEOJSON_DIR" >&2
  exit 1
fi

echo "Processing GeoJSON files: $GEOJSON_FILES" >&2

if ! tippecanoe -o "$OUT_MB" \
    -zg --read-parallel --drop-densest-as-needed \
    --layer=boundaries \
    --force \
    --minimum-zoom=2 \
    --maximum-zoom=10 \
    --simplification=10 \
    --coalesce-densest-as-needed \
    --extend-zooms-if-still-dropping \
    --detect-shared-borders \
    --grid-low-zooms \
    $GEOJSON_FILES; then
  echo "❌ Error: Failed to create vector tiles" >&2
  exit 1
fi

echo "\n✔  Finished: $OUT_MB" >&2
