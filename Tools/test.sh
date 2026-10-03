#!/bin/bash
# Compiles and runs the headless game-logic tests + balance matrix (macOS or Linux, Swift 5.9+).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build-tools
swiftc -swift-version 5 -O HamsterAges/Core/*.swift HamsterAges/Meta/*.swift HamsterAges/Services/Analytics.swift \
  Tools/CoreTests/main.swift -o .build-tools/hamster-tests
.build-tools/hamster-tests | grep -v '\[ANALYTICS\]'
if [[ "${1:-}" == "--balance" ]]; then
  swiftc -swift-version 5 -O HamsterAges/Core/*.swift Tools/SimHarness/main.swift -o .build-tools/hamster-sim
  .build-tools/hamster-sim
fi
