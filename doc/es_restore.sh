#!/bin/bash
# Elasticsearch Restore Script
# Example
# bash es_restore.sh ./es_backup_20260312_103000

ES_HOST="http://172.19.100.76:9200"
ES_USER="elastic"
ES_PASS="changeme"

INDICES=(
  "app-varp-production-2026.01"
  "app-varp-production-2026.02"
  "app-varp-production-2026.03"
)

# --- ระบุ path ของโฟลเดอร์ backup ที่ต้องการ restore ---
BACKUP_DIR="${1:-}"

if [ -z "$BACKUP_DIR" ]; then
  echo "Usage: bash es_restore.sh <backup_directory>"
  echo "Example: bash es_restore.sh ./es_backup_20260312_103000"
  exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
  echo "ERROR: Directory not found: $BACKUP_DIR"
  exit 1
fi

AUTH_HEADER='{"Authorization":"Basic '$(echo -n "${ES_USER}:${ES_PASS}" | base64)'"}'

# Check if elasticdump is installed
if ! command -v elasticdump &> /dev/null; then
  echo "elasticdump not found. Install it with: npm install -g elasticdump"
  exit 1
fi

echo "=== Elasticsearch Restore ==="
echo "Source : $BACKUP_DIR"
echo "Target : $ES_HOST"
echo ""

for INDEX in "${INDICES[@]}"; do
  echo "=== Restoring index: $INDEX ==="

  MAPPING_FILE="${BACKUP_DIR}/${INDEX}_mapping.json"
  SETTINGS_FILE="${BACKUP_DIR}/${INDEX}_settings.json"
  DATA_FILE="${BACKUP_DIR}/${INDEX}_data.json"

  # ตรวจสอบไฟล์
  if [ ! -f "$DATA_FILE" ]; then
    echo "  WARNING: Data file not found, skipping: $DATA_FILE"
    continue
  fi

  # [1] ลบ index เก่าถ้ามีอยู่
  echo "  [1/4] Checking existing index..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${ES_USER}:${ES_PASS}" \
    "${ES_HOST}/${INDEX}")

  if [ "$HTTP_STATUS" == "200" ]; then
    echo "  Index exists. Deleting old index..."
    curl -s -X DELETE "${ES_HOST}/${INDEX}" \
      -u "${ES_USER}:${ES_PASS}" | python3 -m json.tool
    echo "  Old index deleted."
  else
    echo "  Index does not exist. Proceeding..."
  fi

  # [2] Restore settings
  if [ -f "$SETTINGS_FILE" ]; then
    echo "  [2/4] Restoring settings..."
    elasticdump \
      --input="${SETTINGS_FILE}" \
      --output="${ES_HOST}/${INDEX}" \
      --type=settings \
      --headers="${AUTH_HEADER}"
  else
    echo "  [2/4] Settings file not found, skipping..."
  fi

  # [3] Restore mapping
  if [ -f "$MAPPING_FILE" ]; then
    echo "  [3/4] Restoring mapping..."
    elasticdump \
      --input="${MAPPING_FILE}" \
      --output="${ES_HOST}/${INDEX}" \
      --type=mapping \
      --headers="${AUTH_HEADER}"
  else
    echo "  [3/4] Mapping file not found, skipping..."
  fi

  # [4] Restore data
  echo "  [4/4] Restoring data..."
  elasticdump \
    --input="${DATA_FILE}" \
    --output="${ES_HOST}/${INDEX}" \
    --type=data \
    --limit=10000 \
    --headers="${AUTH_HEADER}"

  echo "  Done: $INDEX"
  echo ""
done

echo "=== Restore complete! ==="
echo ""
echo "Verifying restored indices:"
curl -s -u "${ES_USER}:${ES_PASS}" \
  "${ES_HOST}/_cat/indices/app-varp-production-2026.*?v&h=index,docs.count,store.size,health"
