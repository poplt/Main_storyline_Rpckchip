#!/bin/bash
#
# Minimal RockChip-style SDK entry script.
#
# Usage:
#   ./build.sh kernel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RK_SCRIPTS_DIR="$SCRIPT_DIR"

usage()
{
	cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  kernel    Build the kernel and pack it into an extboot partition image.
EOF
}

case "${1:-}" in
	kernel)
		shift
		"$RK_SCRIPTS_DIR/mk-kernel.sh" "$@"
		;;
	help|-h|--help|"")
		usage
		;;
	*)
		echo "Unknown command: $1" >&2
		usage
		exit 1
		;;
esac
