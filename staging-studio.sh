#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Studio [Staging].  Many steps to follow."
echo " Please play along at home..."
echo "---------------------------------------------------"
echo ""
echo ""


BRANCH=$1


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
docker build -t="apicurio/apicurio-studio-api" -t="apicurio/apicurio-studio-api:latest-snapshot" --rm platforms/thorntail/api/
docker build -t="apicurio/apicurio-studio-ws" -t="apicurio/apicurio-studio-ws:latest-snapshot" --rm platforms/thorntail/ws/
docker build -t="apicurio/apicurio-studio-ui" -t="apicurio/apicurio-studio-ui:latest-snapshot" --rm platforms/thorntail/ui/


echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurio-studio-api:latest
docker push apicurio/apicurio-studio-ws:latest
docker push apicurio/apicurio-studio-ui:latest


docker push apicurio/apicurio-studio-api:latest-snapshot
docker push apicurio/apicurio-studio-ws:latest-snapshot
docker push apicurio/apicurio-studio-ui:latest-snapshot


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

