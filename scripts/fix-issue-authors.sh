#!/usr/bin/env bash
# Close issues opened by wrong author and recreate under martinzhames
# Usage: bash fix-issue-authors.sh <repo> <json_file>
set -e
REPO="$1"
JSON_FILE="$2"

echo "Reading issues from $JSON_FILE for $REPO..."

mapfile -t NUMS < <(python3 -c "
import json
d=json.load(open('$JSON_FILE'))
for i in sorted(d, key=lambda x: x['n']):
    print(i['n'])
")

mapfile -t TITLES < <(python3 -c "
import json
d=json.load(open('$JSON_FILE'))
for i in sorted(d, key=lambda x: x['n']):
    print(i['t'])
")

TOTAL=${#NUMS[@]}
echo "Processing $TOTAL issues..."

for i in "${!NUMS[@]}"; do
    NUM="${NUMS[$i]}"
    TITLE="${TITLES[$i]}"
    IDX=$((i+1))

    BODY=$(gh issue view "$NUM" --repo "$REPO" --json body --jq '.body' 2>/dev/null || echo "")

    gh issue close "$NUM" --repo "$REPO" 2>/dev/null

    gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY" 2>/dev/null >/dev/null
    if [ $((IDX % 10)) -eq 0 ]; then echo "[$IDX/$TOTAL] done"; fi
    sleep 0.3
done

echo "Finished $TOTAL issues for $REPO."
