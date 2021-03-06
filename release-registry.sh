#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Registry"
echo "---------------------------------------------------"
echo ""
echo ""


RELEASE_VERSION=$1
RELEASE_NAME=$2
PREVIOUS_RELEASE_VERSION=$3
DEV_VERSION=$4
BRANCH=$5

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

if [ "x$RELEASE_VERSION" = "x" ]
then
  read -p "Release Version: " RELEASE_VERSION
fi

if [ "x$RELEASE_NAME" = "x" ]
then
  read -p "Release Name: " RELEASE_NAME
fi

if [ "x$PREVIOUS_RELEASE_VERSION" = "x" ]
then
  read -p "Previous Release Version: " PREVIOUS_RELEASE_VERSION
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
echo "Release Name:     $RELEASE_NAME"
echo "Previous Version: $PREVIOUS_RELEASE_VERSION"
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


#echo "---------------------------------------------------"
#echo " Downloading and installing GraalVM"
#echo "---------------------------------------------------"
# echo ""
# mkdir -p target
# pushd .
# cd target
# curl https://github.com/oracle/graal/releases/download/vm-19.1.1/graalvm-ce-linux-amd64-19.1.1.tar.gz -O -J -L
# tar xfz graalvm-ce-linux-amd64-19.1.1.tar.gz
# mv graalvm-ce-19.1.1 .graalvm
# cd .graalvm
# GRAALVM_HOME=`pwd`
# export GRAALVM_HOME
# echo "GraalVM downloaded and installed to $GRAALVM_HOME"
# echo "Installing 'native-image'"
# $GRAALVM_HOME/bin/gu install native-image
# popd


echo "---------------------------------------------------"
echo " Checking out required git repos."
echo "---------------------------------------------------"
echo ""
mkdir -p target/git-repos
cd target/git-repos
git clone git@github.com:Apicurio/apicurio-registry.git
git clone git@github.com:apicurio/apicurio-release-tool.git


echo "---------------------------------------------------"
echo " Build the release tool"
echo "---------------------------------------------------"
pushd .
cd apicurio-release-tool
mvn clean install
popd


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apicurio
pushd .
cd apicurio-registry
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
echo "Validating Apicurio Registry maven build"
mvn clean install -Pprod -Pjpa -Pinfinispan -Pkafka -Pstreams -DskipTests
mvn test package -Pprod -Pjpa
mvn verify -Pall -pl tests -Dmaven.javadoc.skip=true

# echo "---------------------------------------------------"
# echo " Validate native build"
# echo "---------------------------------------------------"
# pushd .
# cd apicurio-registry
# ./mvnw clean package verify -Pnative
# popd

echo "---------------------------------------------------"
echo "Commit changes and push to Git"
echo "---------------------------------------------------"
git add .
git commit -m "Prepare for release $RELEASE_VERSION"
git push origin $BRANCH
gpg -s README.md
rm README.md.gpg
git tag -a -s -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION


echo "---------------------------------------------------"
echo "Building docker images."
echo "---------------------------------------------------"
pushd .
cd distro/docker
mvn package -Pprod -DskipTests -Ddocker
mvn package -Pprod -Pjpa -DskipTests -Ddocker
mvn package -Pprod -Pinfinispan -DskipTests -Ddocker
mvn package -Pprod -Pkafka -DskipTests -Ddocker
mvn package -Pprod -Pstreams -DskipTests -Ddocker
popd


echo "---------------------------------------------------"
echo "Releasing Apicurio Registry into Maven Central"
echo "---------------------------------------------------"
mvn deploy -Pprod -Pjpa -Pinfinispan -Pkafka -Pstreams -DskipTests -Prelease -Dgpg.passphrase=$GPG_PASSPHRASE


echo "---------------------------------------------------"
echo "Performing automated GitHub release."
echo "---------------------------------------------------"
java -jar ../apicurio-release-tool/target/apicurio-release-tool.jar -r apicurio-registry --release-name "$RELEASE_NAME" --release-tag $RELEASE_VERSION --previous-tag $PREVIOUS_RELEASE_VERSION --github-pat $GITHUB_AUTH_PAT --output-directory ./target
echo ""


echo "---------------------------------------------------"
echo " Updating version #s for next snapshot version"
echo "---------------------------------------------------"
mvn versions:set -DnewVersion=$DEV_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH
popd


echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurio-registry-mem:latest
docker push apicurio/apicurio-registry-mem:latest-release
docker push apicurio/apicurio-registry-mem:$RELEASE_VERSION
docker push apicurio/apicurio-registry-jpa:latest
docker push apicurio/apicurio-registry-jpa:latest-release
docker push apicurio/apicurio-registry-jpa:$RELEASE_VERSION
docker push apicurio/apicurio-registry-infinispan:latest
docker push apicurio/apicurio-registry-infinispan:latest-release
docker push apicurio/apicurio-registry-infinispan:$RELEASE_VERSION
docker push apicurio/apicurio-registry-kafka:latest
docker push apicurio/apicurio-registry-kafka:latest-release
docker push apicurio/apicurio-registry-kafka:$RELEASE_VERSION
docker push apicurio/apicurio-registry-streams:latest
docker push apicurio/apicurio-registry-streams:latest-release
docker push apicurio/apicurio-registry-streams:$RELEASE_VERSION

echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"
