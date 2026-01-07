#!/bin/bash

set -euo pipefail

# ensure we execute from the repository root so relative paths resolve correctly
script_location_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_location_dir}/../.."

okar-arche/scripts/dl_saxon.sh

echo "downloading saxon"

download_dir="saxon"
mkdir -p "${download_dir}"

curl -LsSf -o "${download_dir}/saxon9he.jar" \
	https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/9.9.1-7/Saxon-HE-9.9.1-7.jar

echo "saxon9he.jar downloaded to ${download_dir}" >&2
