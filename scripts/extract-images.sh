#!/bin/bash

set -e

CHART_PATH=$1
VALUES_FILE=$2
OUTPUT_FILE=${3:-images.txt}

if [ -z "$CHART_PATH" ]; then
    echo "Usage:"
    echo "./extract-images.sh <chart-path> [values-file] [output]"
    exit 1
fi


echo "Extracting images..."

if [ -n "$VALUES_FILE" ]; then

    helm template app \
        "$CHART_PATH" \
        -f "$VALUES_FILE" \
        | grep "image:" \
        | awk '{print $2}' \
        | sort -u > "$OUTPUT_FILE"

else

    helm template app \
        "$CHART_PATH" \
        | grep "image:" \
        | awk '{print $2}' \
        | sort -u > "$OUTPUT_FILE"

fi


echo ""
echo "Images:"
cat "$OUTPUT_FILE"

echo ""
echo "Total:"
wc -l "$OUTPUT_FILE"