#!/bin/bash

# Writes files with x GB size into the current directory and checks the sha checksum later.
# You may run the read check later explicitly with the written test-xxxxx.shasum file.
# I thinks is similar to https://github.com/AltraMayor/f3
# Main avantage for this script:
# - needs not compiler, just "bash", "openssl", "shasum" and default utils.
# - runs much faster on my system
#
# Usage: ./my-f3-check.sh <number-of-giga-bytes-to-test>
# e. g. 32 means 32000000000 bytes
# Usage: ./my-f3-check.sh
# check free local space to find the number of files

if [ -z "${COUNT}" ]; then
  FREE_K=$(df -k .|tail -n 1|awk '{print $4}')
  FREE=$((FREE_K * 1024))
  COUNT=$((FREE / 1000000000))
  echo "Found $FREE free bytes here"
fi

PREFIX=test
LAST=0
ERROR=0

echo "Writing $COUNT files with 1GB = 1.000.000.000 each"

for ((i = 0; i < ${COUNT}; i++)); do
  file=${PREFIX}-$(printf "%05d" $i)
  echo -n "write file ${file} ...       "
  openssl rand 1000000000 | tee ${file} | shasum | sed s/-/${file}/g >${file}.shasum
  echo $((SECONDS - LAST)) s
  LAST=$SECONDS
done

WRITE=${SECONDS}

for ((i = 0; i < ${COUNT}; i++)); do
  file=${PREFIX}-$(printf "%05d" $i)
  echo -n "check file ${file} ... "
  shasum -c ${file}.shasum -s
  RESULT=$?
  if [ "${RESULT}" -eq "0" ]; then
    echo -n "OK    "
  else
    echo -n "ERROR "
  fi
  ERROR=$((ERROR + RESULT))
  echo "$((SECONDS - LAST)) s"
  LAST=$SECONDS
done

READ=$((SECONDS - WRITE))

echo
echo "Found ${ERROR} errors from ${COUNT} tests: $((ERROR * 100 / COUNT)) %"
echo
echo "Writing + random + checksum performance: $((1000 * COUNT / WRITE)) MB/s"
echo "Reading + checksum          performance: $((1000 * COUNT / READ)) MB/s"

if [ $ERROR -gt 0 ]; then
  echo
  echo "*************** check failed! *******************"
  echo
fi
