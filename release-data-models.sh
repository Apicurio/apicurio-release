#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Data Models."
echo "---------------------------------------------------"
echo ""
echo ""


echo "---------------------------------------------------"
echo " Tell me what version we are releasing!"
echo "---------------------------------------------------"
echo ""

RELEASE_VERSION=$1
DEV_VERSION=$2
BRANCH=$3


if [ -f .release.env ]
then
  source ./.release.env
else
  echo "Missing file: .release.env.  Please create this file and add the following env variables:"
  echo "---"
  echo "GITHUB_AUTH_PAT=<your_GitHub_PAT>"
  echo "GPG_PASSPHRASE=<your_GPG_passphrase>"
  echo "---"
  echo ""
  exit 1
fi

if [ "x$GPG_PASSPHRASE" = "x" ]
then
  echo "Environment variable missing from .release.env file: GPG_PASSPHRASE"
fi


if [ "x$RELEASE_VERSION" = "x" ]
then
  read -p "Release Version: " RELEASE_VERSION
fi

if [ "x$DEV_VERSION" = "x" ]
then
  read -p "New Development Version: " DEV_VERSION
fi

if [ "x$BRANCH" = "x" ]
then
  read -p "Release Branch: [master] " BRANCH
fi
if [ "x$BRANCH" = "x" ]
then
  BRANCH=master
fi


echo "######################################"
echo "Release Version:  $RELEASE_VERSION"
echo "Next Dev Version: $DEV_VERSION"
echo "Branch:           $BRANCH"
echo "######################################"
echo ""


echo "---------------------------------------------------"
echo " Resetting 'target' directory."
echo "---------------------------------------------------"
echo ""
rm -rf target
mkdir -p target


echo "---------------------------------------------------"
echo " Checking out required git repos."
echo "---------------------------------------------------"
echo ""
mkdir -p target/git-repos
cd target/git-repos
git clone git@github.com:apicurio/apicurio-data-models.git


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apicurio
pushd .
cd apicurio-data-models
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
echo "Validating Apicurio Data Models maven build"
mvn clean install -Ptranspilation


echo "Commit changes and push to Git"
echo "---------------------------------------------------"
git add .
git commit -m "Prepare for release v$RELEASE_VERSION"
git push origin $BRANCH
gpg -s README.md
rm README.md.gpg
git tag -a -s -m "Tagging release v$RELEASE_VERSION" v$RELEASE_VERSION
git push origin v$RELEASE_VERSION


echo "---------------------------------------------------"
echo "Releasing Apicurio Data Models into Maven Central"
echo "---------------------------------------------------"
mvn clean deploy -Prelease -Dgpg.passphrase=$GPG_PASSPHRASE


echo "---------------------------------------------------"
echo "Releasing Apicurio Data Models into NPM"
echo "---------------------------------------------------"
pushd .
cd target/ts
sed -i "s/.Final//g" ./dist/package.json
npm publish ./dist
popd


echo "---------------------------------------------------"
echo " Updating version #s for next snapshot version"
echo "---------------------------------------------------"
mvn versions:set -DnewVersion=$DEV_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH
popd


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

