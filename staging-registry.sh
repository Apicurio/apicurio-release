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
./mvnw clean install -Pprod -Pjpa -Pinfinispan -Pkafka -Pstreams -DskipTests
./mvnw test package -Pprod -Pjpa
./mvnw verify -Pall -pl tests -Dmaven.javadoc.skip=true
popd


echo "---------------------------------------------------"
echo "Building docker images."
echo "---------------------------------------------------"
pushd .
cd apicurio-registry/distro/docker
mvn package -Pprod -DskipTests -Ddocker -Ddocker.tag.name=latest-snapshot
mvn package -Pprod -Pjpa -DskipTests -Ddocker -Ddocker.tag.name=latest-snapshot
mvn package -Pprod -Pinfinispan -DskipTests -Ddocker -Ddocker.tag.name=latest-snapshot
mvn package -Pprod -Pkafka -DskipTests -Ddocker -Ddocker.tag.name=latest-snapshot
mvn package -Pprod -Pstreams -DskipTests -Ddocker -Ddocker.tag.name=latest-snapshot
popd


# echo "---------------------------------------------------"
# echo "Pushing docker images."
# echo "---------------------------------------------------"
docker push apicurio/apicurio-registry-mem:latest-snapshot
docker push apicurio/apicurio-registry-jpa:latest-snapshot
docker push apicurio/apicurio-registry-infinispan:latest-snapshot
docker push apicurio/apicurio-registry-kafka:latest-snapshot
docker push apicurio/apicurio-registry-streams:latest-snapshot

echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

