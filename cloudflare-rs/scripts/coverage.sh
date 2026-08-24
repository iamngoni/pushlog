#!/bin/sh
# Enforces host coverage for runtime-independent production code.
# Worker/D1 adapters execute in workerd instead and are covered by
# `npm run test:integration`; LLVM cannot instrument that WASM runtime.

set -eu

cargo llvm-cov \
  --all-features \
  --lib \
  --fail-under-lines 95 \
  --ignore-filename-regex 'src/(auth|devices|env|error|friends|lib|notifications|profile|workout)\.rs|src/push/'
