#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Registry [Staging]."
echo "---------------------------------------------------"
echo ""
echo ""


BRANCH=$1

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

if [ "x$GITHUB_AUTH_PAT" = "x" ]
then
  echo "Environment variable missing from .release.env file: GITHUB_AUTH_PAT"
fi
if [ "x$GPG_PASSPHRASE" = "x" ]
then
  echo "Environment variable missing from .release.env file: GPG_PASSPHRASE"
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
echo "Branch:           $BRANCH"
echo "######################################"
echo ""


echo "---------------------------------------------------"
echo " Resetting 'target' directory."
echo "---------------------------------------------------"
echo ""
rm -rf target
mkdir -p target
cp README.md target/README.md
gpg -s target/README.md
rm target/README.md.gpg


echo "---------------------------------------------------"
echo " Downloading and installing GraalVM"
echo "---------------------------------------------------"
echo ""
mkdir -p target
pushd .
cd target
curl https://github.com/oracle/graal/releases/download/vm-19.1.1/graalvm-ce-linux-amd64-19.1.1.tar.gz -O -J -L
tar xfz graalvm-ce-linux-amd64-19.1.1.tar.gz
mv graalvm-ce-19.1.1 .graalvm
cd .graalvm
GRAALVM_HOME=`pwd`
export GRAALVM_HOME
echo "GraalVM downloaded and installed to $GRAALVM_HOME"
echo "Installing 'native-image'"
$GRAALVM_HOME/bin/gu install native-image
popd


echo "---------------------------------------------------"
echo " Checking out required git repos."
echo "---------------------------------------------------"
echo ""
mkdir -p target/git-repos
cd target/git-repos
git clone git@github.com:Apicurio/apicurio-registry.git


echo "---------------------------------------------------"
echo " Validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apicurio
pushd .
cd apicurio-registry
git checkout $BRANCH
./mvnw clean package
popd


echo "---------------------------------------------------"
echo " Validate native build"
echo "---------------------------------------------------"
pushd .
cd apicurio-registry
./mvnw clean package verify -Pnative
popd


echo "---------------------------------------------------"
echo "Building docker images."
echo "---------------------------------------------------"
pushd .
cd apicurio-registry/
docker build -t="apicurio/apicurio-registry" -t="apicurio/apicurio-registry:latest-snapshot" -f distro/app-docker/src/main/docker/Dockerfile.native .
popd

echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurito-registry:latest
docker push apicurio/apicurito-registry:latest-snapshot

echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

