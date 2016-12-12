#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */*/ )
fi
versions=( "${versions[@]%/}" )

debian="$(curl -fsSL 'https://raw.githubusercontent.com/docker-library/official-images/master/library/debian')"
ubuntu="$(curl -fsSL 'https://raw.githubusercontent.com/docker-library/official-images/master/library/ubuntu')"

travisEnv=
for version in "${versions[@]}"; do
	if echo "$debian" | grep -qE "\b${version%/*}\b"; then
		dist='debian'
	elif echo "$ubuntu" | grep -qE "\b${version%/*}\b"; then
		dist='ubuntu'
	else
		echo >&2 "error: cannot determine repo for '$version'"
		exit 1
	fi

	if ! grep -q '^# GENERATED' $version/Dockerfile; then
		travisEnv+='\n  - VERSION='"$version"
		continue
	fi

	for variant in curl scm ''; do
		src="Dockerfile${variant:+-$variant}.template"
		trg="$version${variant:+/$variant}/Dockerfile"
		mkdir -p "$(dirname "$trg")"
		( set -x && sed '
			s!DIST!'"$dist"'!g;
			s!SUITE!'"${version%/*}"'!g;
			s!ARCH!'"${version#*/}"'!g;
		' "$src" > "$trg" )
	done
	travisEnv+='\n  - VERSION='"$version"
done

travis="$(awk -v 'RS=\n\n' '($1 == "env:") { $0 = substr($0, 0, index($0, "matrix:") + length("matrix:"))"'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
