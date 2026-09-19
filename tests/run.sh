#!/bin/sh
# run.sh — lance tous les tests de NeoDOS (make test)
cd "$(dirname "$0")/.." && exec python3 tests/run_tests.py "$@"
