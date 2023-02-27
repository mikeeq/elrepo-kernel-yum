#!/bin/bash

set -eu -o pipefail

echo >&2 "===]> Info: Build yum-repo..."
docker build -t yum-repo .

echo >&2 "===]> Info: Run yum-repo in the background..."
DOCKER_CONTAINER_ID=$(docker run --rm -d yum-repo)

echo >&2 "===]> Info: Make a zip file with repo content..."
docker exec -t -u 0 "$DOCKER_CONTAINER_ID" /bin/bash -c '
dnf makecache
dnf install -y zip unzip curl cmake
cd /tmp
curl -L https://github.com/libthinkpad/apindex/archive/refs/tags/2.2.zip -O
unzip 2.2.zip
cd apindex-2.2
cmake . -DCMAKE_INSTALL_PREFIX=/usr
make install
cd /var/repo
apindex .
zip -r /tmp/repo.zip ./
'

echo >&2 "===]> Info: Copy zip file to host..."
docker cp "$DOCKER_CONTAINER_ID":/tmp/repo.zip /tmp/repo.zip

echo >&2 "===]> Info: Change branch to gh-pages..."
git fetch origin gh-pages
git checkout gh-pages

echo >&2 "===]> Info: Remove old RPMs..."
rm -rfv ./*.rpm
rm -rfv ./repodata
rm -rfv ./index.html
rm -rfv ./yum-repo

echo >&2 "===]> Info: Copy zip file to repo..."
cp -rfv /tmp/repo.zip ./

echo >&2 "===]> Info: Unzip..."
unzip repo.zip

echo >&2 "===]> Info: Remove zip..."
rm -rfv repo.zip

echo >&2 "===]> Info: Add git config..."
git config user.name "CI-GitHubActions"
git config user.email "ci@github-actions.com"

echo >&2 "===]> Info: Add, commit, push changes to gh-pages remote..."
git add .
git commit -m "Release: $LATEST_RELEASE, date: $(date +'%Y%m%d_%H%M%S')"
git push origin gh-pages

echo >&2 "===]> Info: Stop yum-repo container..."
docker stop "$DOCKER_CONTAINER_ID"
