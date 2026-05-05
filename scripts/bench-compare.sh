#!/usr/bin/env bash
# bench-compare.sh — orchestrator: runs bench-runner.sh on the host (WSL2 native)
# and inside sb-claude (docker exec), then prints a side-by-side ratio table.
#
# Usage:
#   ./bench-compare.sh                # print table to stdout
#   ./bench-compare.sh --raw          # also dump raw KEY=VALUE outputs

set -euo pipefail

CONTAINER="${CONTAINER:-sb-claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/bench-runner.sh"
RAW=0
[[ "${1:-}" == "--raw" ]] && RAW=1

[[ -f "$RUNNER" ]] || { echo "missing $RUNNER" >&2; exit 1; }
docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -qx true \
  || { echo "container '$CONTAINER' is not running" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/2] running native..." >&2
bash "$RUNNER" > "$TMP/native.txt"

echo "[2/2] running in $CONTAINER..." >&2
docker exec -i "$CONTAINER" bash -s < "$RUNNER" > "$TMP/docker.txt"

if (( RAW )); then
  echo "=== NATIVE ==="; cat "$TMP/native.txt"
  echo "=== DOCKER ==="; cat "$TMP/docker.txt"
  echo "=============="
fi

# Side-by-side table with ratio. Higher = slower in docker for *_ms metrics.
perl - "$TMP/native.txt" "$TMP/docker.txt" <<'PERL'
use strict; use warnings;
my ($n_path, $d_path) = @ARGV;

sub load { my %h; open my $fh,'<',$_[0] or die $!;
  while(<$fh>){ chomp; next unless /^([^=]+)=(.*)$/; $h{$1}=$2 } \%h }
my $N = load($n_path);
my $D = load($d_path);

# Preserve order from the runner script.
my @order = qw(
  fs_read_corpus_n
  fs_read_bind_ms fs_stat_bind_ms fs_write_bind_ms fs_write_tmp_ms
  fs_read_large_100mb_ms
  proc_bash_per_ms
  net_dns_5x_ms net_tls_3x_ms
  cpu_sha256_100mb_ms
  meta_kernel meta_user meta_in_container meta_vault_fs meta_tmp_fs meta_cpu_model
);

printf "\n%-26s %14s %14s %10s  %s\n", "metric","native","docker","ratio","flag";
printf "%-26s %14s %14s %10s  %s\n", '-' x 26,'-' x 14,'-' x 14,'-' x 10,'----';
for my $k (@order) {
  my $n = $N->{$k} // '-';
  my $d = $D->{$k} // '-';
  my ($ratio,$flag) = ('','');
  if ($n =~ /^[0-9.]+$/ && $d =~ /^[0-9.]+$/ && $n > 0) {
    $ratio = sprintf "%.2fx", $d/$n;
    if ($k =~ /_ms$/ || $k =~ /_per_ms$/) {
      $flag = '!!' if $d/$n >= 2.0;
      $flag = '!'  if !$flag && $d/$n >= 1.5;
    }
  }
  printf "%-26s %14s %14s %10s  %s\n", $k, $n, $d, $ratio, $flag;
}
print "\nratio = docker / native. for *_ms metrics, higher = docker slower.\n";
print "flag: ! >=1.5x, !! >=2.0x.\n";
PERL
