#!/usr/bin/env bash
# bench-runner.sh — single-environment microbenchmarks.
#
# Runs in either WSL2 native or sb-claude container. Prints KEY=VALUE lines
# on stdout. Designed to be paired with bench-compare.sh which executes this
# in both envs and diffs the output.
#
# Tools required: bash 5+, awk, perl, openssl, curl, dd, getent. No jq/python.

set -euo pipefail

VAULT="${VAULT:-$HOME/projects/2nd-brain-vault}"
WRITE_DIR="${VAULT}/.bench-tmp.$$"
TMP_DIR="$(mktemp -d /tmp/bench.XXXXXX)"
mkdir -p "$WRITE_DIR"
trap 'rm -rf "$WRITE_DIR" "$TMP_DIR"' EXIT

now()        { printf '%s\n' "$EPOCHREALTIME"; }
elapsed_ms() { awk -v s="$1" -v e="$2" 'BEGIN{printf "%.2f", (e-s)*1000}'; }

# Read corpus: stable, deterministic-ish set of files inside the vault.
# Both envs see the same vault via bind mount, so corpus is identical.
mapfile -t CORPUS < <(find "$VAULT/knowledge" -type f -name '*.md' 2>/dev/null | sort | head -200)
if (( ${#CORPUS[@]} < 20 )); then
  mapfile -t CORPUS < <(find "$VAULT" -type f 2>/dev/null | sort | head -100)
fi
echo "fs_read_corpus_n=${#CORPUS[@]}"

########## FS: bind-mount read (warmup + measure) ##########
for f in "${CORPUS[@]}"; do cat "$f" >/dev/null; done
S=$(now)
for f in "${CORPUS[@]}"; do cat "$f" >/dev/null; done
E=$(now)
echo "fs_read_bind_ms=$(elapsed_ms "$S" "$E")"

########## FS: bind-mount stat walk ##########
S=$(now)
find "$VAULT/knowledge" -type f 2>/dev/null | head -1000 | xargs -r stat -c '%s' >/dev/null
E=$(now)
echo "fs_stat_bind_ms=$(elapsed_ms "$S" "$E")"

########## FS: bind-mount small write (100 × ~5B) ##########
S=$(now)
for i in $(seq 1 100); do echo "x" > "$WRITE_DIR/f$i"; done
sync
E=$(now)
echo "fs_write_bind_ms=$(elapsed_ms "$S" "$E")"

########## FS: /tmp small write (overlayfs in container, tmpfs/ext4 native) ##########
S=$(now)
for i in $(seq 1 100); do echo "x" > "$TMP_DIR/f$i"; done
sync
E=$(now)
echo "fs_write_tmp_ms=$(elapsed_ms "$S" "$E")"

########## FS: large sequential read (cached, in-vault) ##########
LARGE="$WRITE_DIR/large.bin"
dd if=/dev/zero of="$LARGE" bs=1M count=100 status=none
sync
dd if="$LARGE" of=/dev/null bs=1M status=none  # warmup
S=$(now)
dd if="$LARGE" of=/dev/null bs=1M status=none
E=$(now)
echo "fs_read_large_100mb_ms=$(elapsed_ms "$S" "$E")"

########## Process: bash spawn × 200 ##########
S=$(now)
for i in $(seq 1 200); do bash -c 'true'; done
E=$(now)
TOTAL=$(elapsed_ms "$S" "$E")
echo "proc_bash_per_ms=$(awk -v t="$TOTAL" 'BEGIN{printf "%.3f", t/200}')"

########## Network: DNS × 5 ##########
S=$(now)
for i in 1 2 3 4 5; do getent hosts api.anthropic.com >/dev/null; done
E=$(now)
echo "net_dns_5x_ms=$(elapsed_ms "$S" "$E")"

########## Network: TCP+TLS handshake × 3 (curl -w with no body) ##########
S=$(now)
for i in 1 2 3; do
  curl -s -o /dev/null -w '' --connect-timeout 5 --max-time 8 \
    'https://api.anthropic.com/' 2>/dev/null || true
done
E=$(now)
echo "net_tls_3x_ms=$(elapsed_ms "$S" "$E")"

########## CPU: sha256 of 100 MB ##########
S=$(now)
dd if=/dev/zero bs=1M count=100 status=none | openssl dgst -sha256 >/dev/null
E=$(now)
echo "cpu_sha256_100mb_ms=$(elapsed_ms "$S" "$E")"

########## Meta ##########
echo "meta_kernel=$(uname -r)"
echo "meta_user=$(id -un)"
echo "meta_in_container=$([ -f /.dockerenv ] && echo yes || echo no)"
echo "meta_vault_fs=$(df -T "$VAULT" 2>/dev/null | awk 'NR==2{print $2}')"
echo "meta_tmp_fs=$(df -T /tmp 2>/dev/null | awk 'NR==2{print $2}')"
echo "meta_cpu_model=$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ *//')"
