#!/usr/bin/env bash
# Install a checksum-verified source release without starting the API or copying secrets.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: stage-release.sh ARCHIVE RELEASE_NAME' >&2; exit 1; }
archive=$1
release_name=$2
[[ $archive =~ ^astha-vm-[0-9]+\.tar\.gz$ ]] || exit 1
[[ $release_name =~ ^web-[0-9-]+$ ]] || exit 1
[[ $(id -un) == ciroeduardoarrudacosta ]] || exit 1
cd "$HOME/.astha-deploy"
sha256sum --check "$archive.sha256"
release=/opt/astha/releases/$release_name
[[ ! -e $release ]] || { echo 'Release directory already exists; refusing overwrite.' >&2; exit 1; }
mkdir -m 755 "$release"
tar -xzf "$archive" -C "$release" --no-same-owner --no-same-permissions
export PATH=/opt/astha/node/bin:$PATH
cd "$release/api"
npm ci --omit=dev --ignore-scripts --no-audit --no-fund
node --check server.js
node --check production-start.cjs
node -e "for(const name of ['express','mysql2/promise','jsonwebtoken','helmet','cors'])require(name);console.log('RUNTIME_DEPENDENCIES_OK')"
ln -s "$release" /opt/astha/releases/current.candidate
mv -Tf /opt/astha/releases/current.candidate /opt/astha/releases/current
printf '%s\n' "RELEASE_STAGED $release - application service was not started."
