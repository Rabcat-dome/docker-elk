#!/bin/bash
# Elasticsearch Backup Script
# Example
# bash es_backup.sh

ES_HOST="http://172.19.100.56:9200"
ES_USER="elastic"
ES_PASS="changeme"
BACKUP_DIR="./es_backup_$(date +%Y%m%d_%H%M%S)"

INDICES=(
  "app-varp-production-2026.01"
  "app-varp-production-2026.02"
  "app-varp-production-2026.03"
)

mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"

# Check if elasticdump is installed
if ! command -v elasticdump &> /dev/null; then
  echo "elasticdump not found. Install it with: npm install -g elasticdump"
  exit 1
fi

for INDEX in "${INDICES[@]}"; do
  echo ""
  echo "=== Backing up index: $INDEX ==="

  # Backup mapping
  echo "  [1/3] Exporting mapping..."
  elasticdump \
    --input="${ES_HOST}/${INDEX}" \
    --output="${BACKUP_DIR}/${INDEX}_mapping.json" \
    --type=mapping \
    --headers='{"Authorization":"Basic '$(echo -n "${ES_USER}:${ES_PASS}" | base64)'"}'
    #--httpAuthFile=/dev/null

  # Backup settings
  echo "  [2/3] Exporting settings..."
  elasticdump \
    --input="${ES_HOST}/${INDEX}" \
    --output="${BACKUP_DIR}/${INDEX}_settings.json" \
    --type=settings \
    --headers='{"Authorization":"Basic '$(echo -n "${ES_USER}:${ES_PASS}" | base64)'"}'

  # Backup data
  echo "  [3/3] Exporting data..."
  elasticdump \
    --input="${ES_HOST}/${INDEX}" \
    --output="${BACKUP_DIR}/${INDEX}_data.json" \
    --type=data \
    --limit=10000 \
    --headers='{"Authorization":"Basic '$(echo -n "${ES_USER}:${ES_PASS}" | base64)'"}'

  echo "  Done: $INDEX"
done

echo "=== Backup complete! Files saved to: $BACKUP_DIR ==="
ls -lh "$BACKUP_DIR"
