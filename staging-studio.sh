#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Studio [Staging].  Many steps to follow."
echo " Please play along at home..."
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
echo " Checking out required git repos."
echo "---------------------------------------------------"
echo ""
mkdir -p target/git-repos
cd target/git-repos
git clone git@github.com:apicurio/apicurio-studio.git


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apicurio
pushd .
cd apicurio-studio
git checkout $BRANCH
mvn clean install


echo "---------------------------------------------------"
echo "Creating Docker images."
echo "---------------------------------------------------"
docker build -t="apicurio/apicurio-studio-api" -t="apicurio/apicurio-studio-api:latest-snapshot" --rm platforms/swarm/api/
docker build -t="apicurio/apicurio-studio-ws" -t="apicurio/apicurio-studio-ws:latest-snapshot" --rm platforms/swarm/ws/
docker build -t="apicurio/apicurio-studio-ui" -t="apicurio/apicurio-studio-ui:latest-snapshot" --rm platforms/swarm/ui/


echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurio-studio-api
docker push apicurio/apicurio-studio-ws
docker push apicurio/apicurio-studio-ui


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

