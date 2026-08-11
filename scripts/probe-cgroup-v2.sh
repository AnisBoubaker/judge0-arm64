#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ "$(uname -m)" == "aarch64" ]] || fail "expected aarch64, got $(uname -m)"
[[ -f /sys/fs/cgroup/cgroup.controllers ]] || fail "unified cgroup v2 hierarchy is not visible"
pass "ARM64 and cgroup v2 are visible"

controllers="$(cat /sys/fs/cgroup/cgroup.controllers)"
[[ " $controllers " == *" memory "* ]] || fail "memory controller unavailable: $controllers"
[[ " $controllers " == *" cpu "* ]] || fail "cpu controller unavailable: $controllers"
[[ " $controllers " == *" pids "* ]] || fail "pids controller unavailable: $controllers"
pass "cpu, memory, and pids controllers are available"

test_root=/sys/fs/cgroup/judge0-poc-probe
if mkdir "$test_root" 2>/dev/null; then
  trap 'rmdir "$test_root" 2>/dev/null || true' EXIT
  printf '33554432' > "$test_root/memory.max"
  printf '16' > "$test_root/pids.max"
  [[ "$(cat "$test_root/memory.max")" == "33554432" ]] || fail "memory.max was not applied"
  [[ "$(cat "$test_root/pids.max")" == "16" ]] || fail "pids.max was not applied"
  pass "a writable child cgroup accepts memory and process limits"
else
  fail "cgroup hierarchy is read-only or delegation is unavailable"
fi

isolate --version
pass "kernel capability probe completed"

