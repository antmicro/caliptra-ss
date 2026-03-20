#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
    echo "Usage: $0 <input file> <output file> [flash_size_bytes]"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
FLASH_SIZE="${3:-33554432}"  # default: 32 MiB

if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT"
    exit 1
fi

size=$(stat -c%s "$INPUT")
size_words=$(( size / 4 ))

dd if=/dev/zero ibs=1 count="$FLASH_SIZE" status=none | tr "\000" "\377" > "$OUTPUT"

printf '%b' \
    "$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' \
        $((size_words & 0xff)) \
        $(((size_words >> 8) & 0xff)) \
        $(((size_words >> 16) & 0xff)) \
        $(((size_words >> 24) & 0xff)))" \
        | dd of="$OUTPUT" bs=1 seek=0 conv=notrunc status=none

dd if="$INPUT" of="$OUTPUT" bs=1 seek=4 conv=notrunc status=none
