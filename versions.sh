#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

suite="$1"
versions=( "${@:2}" )
json='{}'

packagesUrl='https://sourceware.org/pub/gcc/releases/?C=M;O=D' # the actual HTML of the page changes based on which mirror we end up hitting, *and* sometimes specific mirrors are missing versions, so let's hit the original canonical host for version scraping
packages="$(wget -qO- "$packagesUrl")"

for version in "${versions[@]}"; do
	fullVersion="$(grep -P '<a href="(gcc-)?\Q'"$version"'\E' <<<"$packages" | sed -r 's!.*<a href="(gcc-)?([^"/]+)/?".*!\2!' | sort -V | tail -1)"

	compression=
	for tryCompression in xz bz2 gz; do
		if \
			wget --quiet --spider "$packagesUrl/gcc-$fullVersion/gcc-$fullVersion.tar.$tryCompression" \
			|| wget --quiet --spider "$packagesUrl/$fullVersion/gcc-$fullVersion.tar.$tryCompression" \
		; then
			compression="$tryCompression"
			break
		fi
	done
	if [ -z "$compression" ]; then
		echo >&2 "error: $fullVersion does not seem to even really exist"
		exit 1
	fi

	echo "$version: $fullVersion; $suite, $compression"

	export version fullVersion suite compression
	json="$(jq <<<"$json" -c '
		.[env.version] = {
			version: env.fullVersion,
			compression: env.compression,
			ubuntu: {
				version: env.suite,
			},
		}
	')"
done

jq <<<"$json" -S . > versions.json
