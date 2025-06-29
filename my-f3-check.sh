#!/bin/bash

# Writes files with x GB size into the current directory and checks the sha checksum later.
# You may run the read check later explicitly with the written test-xxxxx.shasum file.
# I thinks is similar to https://github.com/AltraMayor/f3
# Main avantage for this script:
# - needs not compiler, just "bash", "openssl", "shasum" and default utils.
# - runs much faster on my system

# Check Parameters

if [[ $# -eq 1 && "$1" =~ ^-?[0-9]+$ && "$1" -ge -1 ]]; then
  MAX=$1
  if (( MAX == -1 )); then
    unset MAX
  fi
#  echo "number-of-gigabytes-to-test = $MAX"
else
  echo "Error: Exactly one integer argument (≥ -1) is required."
  echo "Usage: ./my-f3-check.sh <number-of-gigabytes-to-test>"
  echo "Usage: number-of-gigabytes-to-test == -1: write until the device is full"
  echo "Usage: number-of-gigabytes-to-test == 0: don't write, only check"
  echo "Usage: number-of-gigabytes-to-test >= 1: write maximum number of files 1 GB each"
  exit 1
fi

# Check old corrupt files

for shasum_file in test-*.shasum; do

  [[ -e "$shasum_file" && "$shasum_file" =~ ^test-([0-9]+)\.shasum$ ]] || continue

  num="${shasum_file#test-}"
  num="${num%.shasum}"

  if [ ! -s "$shasum_file" ]; then
    echo "$(date) - Delete empty file: $shasum_file"
    rm -f "$shasum_file"

    base_file="test-$num"
    if [ -f "$base_file" ]; then
      echo "$(date) - Delete belonging data file: $base_file"
      rm -f "$base_file"
    fi
  fi
done

# check free space

if [ -z "$MAX" ]; then
  FREE_K=$(df -k .|tail -n 1|awk '{print $4}')
  FREE=$((FREE_K  * 1024))
  MAX=$((FREE / 1000000000))
  echo "$(date) - Found $FREE free bytes here - set MAX to $MAX"
fi

LAST=0
ERROR=0
COUNT=0

# Höchste bisherige Zahl ermitteln

NEXT=-1
for file in test-[0-9]*.shasum; do
  [[ -e "$file" && "$file" =~ ^test-([0-9]+).shasum$ ]] || continue
  num=${BASH_REMATCH[1]}
  # remove trailing zeros
  num=$((10#$num))
  if (( num > NEXT )); then
    NEXT=$num
  fi
done

# Write test files

echo "$(date) - Try to write $MAX files with 1GB = 1.000.000.000 each"

for ((i = 1; i <= MAX; i++)); do

  ((NEXT++))

  FREE_K=$(df -k .|tail -n 1|awk '{print $4}')
  FREE=$((FREE_K  * 1024))

  if (( FREE >= 1001000000)); then
    file=test-$(printf "%05d" $NEXT)
    echo -n "$(date) - write file ${file} ...       "
    openssl rand 1000000000 | tee ${file} | shasum | sed s/-/${file}/g >${file}.shasum
    echo $((SECONDS - LAST)) s
    LAST=$SECONDS
  else
    break
  fi
done

WRITE=${SECONDS}

for file in test-*.shasum; do

  [[ -e "$file" && "$file" =~ ^test-([0-9]+)\.shasum$ ]] || continue

  echo -n "$(date) - Check file ${file} ... "
  shasum -c ${file} -s
  RESULT=$?
  if [ "${RESULT}" -eq "0" ]; then
    echo -n "OK    "
  else
    echo -n "ERROR "
  fi
  ERROR=$((ERROR + RESULT))
  echo "$((SECONDS - LAST)) s"
  LAST=$SECONDS
  ((COUNT++))
done

READ=$((SECONDS - WRITE))

if [ $COUNT -gt 0 ]; then
  WRITE_PERF=$([[ $WRITE -eq 0 ]] && echo "n/a" || echo $((1000 * COUNT / WRITE)))
  READ_PERF=$([[ $READ -eq 0 ]] && echo "n/a" || echo $((1000 * COUNT / READ)))
  echo
  echo "Found ${ERROR} errors from $COUNT tests: $((ERROR * 100 / COUNT)) %"
  echo
  echo "Writing + random + checksum performance: $WRITE_PERF MB/s"
  echo "Reading + checksum          performance: $READ_PERF MB/s"
else
  echo "Nothing checked!"
fi

if [ $ERROR -gt 0 ]; then
  echo
  echo "*************** check failed! *******************"
  echo
  exit 1
fi
