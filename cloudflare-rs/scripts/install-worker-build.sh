#!/usr/bin/env bash
set -euo pipefail

readonly worker_build_version="0.8.5"
readonly worker_build_sha256="06c489585a93ce94210df365a879c8a5ceab27f4d2c380484c26642469e78a36"
readonly worker_build_url="https://static.crates.io/crates/worker-build/worker-build-${worker_build_version}.crate"

if command -v worker-build >/dev/null &&
  [ "$(worker-build --version)" = "$worker_build_version" ]; then
  exec worker-build "$@"
fi

# worker-build uses native-tls. The self-hosted runner intentionally executes
# without root privileges, so it cannot apt-install OpenSSL headers. When the
# system development package is unavailable, enable openssl's vendored feature
# in the verified crates.io source and compile it entirely under Cargo's user
# directory instead.
if command -v pkg-config >/dev/null && pkg-config --exists openssl; then
  cargo install --locked --version "$worker_build_version" worker-build
  exec "${CARGO_HOME:-$HOME/.cargo}/bin/worker-build" "$@"
fi

for required_command in curl tar cargo; do
  if ! command -v "$required_command" >/dev/null; then
    echo "Installing worker-build requires $required_command." >&2
    exit 1
  fi
done

worker_build_temp_root="$(mktemp -d "${TMPDIR:-/tmp}/pushlog-worker-build.XXXXXX")"
trap 'rm -rf "$worker_build_temp_root"' EXIT

worker_build_archive="$worker_build_temp_root/worker-build.crate"
curl --fail --location --silent --show-error \
  "$worker_build_url" \
  --output "$worker_build_archive"

if command -v sha256sum >/dev/null; then
  worker_build_actual_sha256="$(sha256sum "$worker_build_archive" | cut -d ' ' -f 1)"
else
  worker_build_actual_sha256="$(shasum -a 256 "$worker_build_archive" | cut -d ' ' -f 1)"
fi

if [ "$worker_build_actual_sha256" != "$worker_build_sha256" ]; then
  echo "worker-build archive checksum did not match the pinned release." >&2
  exit 1
fi

tar -xzf "$worker_build_archive" --directory "$worker_build_temp_root"
worker_build_source="$worker_build_temp_root/worker-build-$worker_build_version"

cat >>"$worker_build_source/Cargo.toml" <<'EOF'

[dependencies.openssl]
version = "=0.10.81"
features = ["vendored"]
EOF

# Refresh only the temporary package lock after enabling the vendored feature,
# then require that lock for the actual installation.
cargo metadata \
  --format-version 1 \
  --manifest-path "$worker_build_source/Cargo.toml" \
  >/dev/null
cargo install --locked --path "$worker_build_source"
exec "${CARGO_HOME:-$HOME/.cargo}/bin/worker-build" "$@"
