#!/bin/sh
# Enforces host coverage for runtime-independent production code.
# Worker/D1/AI adapters require the Workers runtime, which LLVM cannot
# instrument. Integration tests exercise HTTP/D1; unit tests cover AI output.

set -eu

cargo llvm-cov \
  --all-features \
  --lib \
  --fail-under-lines 95 \
  --ignore-filename-regex 'src/(auth|devices|engagement|engagement_copy|env|error|friends|lead_change_copy|lib|notifications|profile|workout)\.rs|src/push/'
