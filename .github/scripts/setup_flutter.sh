#!/usr/bin/env bash

# Flutter does not publish Linux ARM64 SDK archives, so the standard setup
# action cannot install Flutter on Pushlog's self-hosted ARM64 runner. A source
# checkout bootstraps the matching ARM64 Dart SDK and Flutter artifacts.
set -euo pipefail

readonly FLUTTER_VERSION="3.44.8"
readonly FLUTTER_ROOT="${RUNNER_TEMP}/pushlog-flutter-${FLUTTER_VERSION}"

git clone \
  --branch "${FLUTTER_VERSION}" \
  --depth 1 \
  https://github.com/flutter/flutter.git \
  "${FLUTTER_ROOT}"

echo "${FLUTTER_ROOT}/bin" >> "${GITHUB_PATH}"

"${FLUTTER_ROOT}/bin/flutter" config --no-analytics
"${FLUTTER_ROOT}/bin/flutter" --version
