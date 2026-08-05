#!/bin/sh

# Prepare Flutter and CocoaPods in Xcode Cloud's ephemeral build environment.
set -eu

readonly FLUTTER_VERSION="3.44.8"
readonly FLUTTER_HOME="${HOME}/flutter"

cd "${CI_PRIMARY_REPOSITORY_PATH}"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  git clone \
    --branch "${FLUTTER_VERSION}" \
    --depth 1 \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
export HOMEBREW_NO_AUTO_UPDATE=1

flutter config --no-analytics
flutter precache --ios
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

cd ios
pod install
