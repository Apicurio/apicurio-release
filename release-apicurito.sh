#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurito.  Many steps to follow."
echo " Please play along at home..."
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
cp README.md target/README.md
gpg -s target/README.md
rm target/README.md.gpg


echo "---------------------------------------------------"
echo " Checking out required git repos."
echo "---------------------------------------------------"
echo ""
mkdir -p target/git-repos
cd target/git-repos
git clone git@github.com:apicurio/apicurito.git
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
cd apicurito
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
sed -i "s/version.:.*/version\": \"$RELEASE_VERSION\",/g" ui/package.json
mvn clean install -D::image
git add ui/package.json pom.xml ui/pom.xml
git commit -m "Prepare for release $RELEASE_VERSION" -s -S
git push origin $BRANCH
git tag -a -s -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION


echo "---------------------------------------------------"
echo "Performing automated GitHub release."
echo "---------------------------------------------------"
java -jar ../apicurio-release-tool/target/apicurio-release-tool.jar -r apicurito --release-name "$RELEASE_NAME" --release-tag $RELEASE_VERSION --previous-tag $PREVIOUS_RELEASE_VERSION --github-pat $GITHUB_AUTH_PAT --output-directory ./target
echo ""


echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurito-ui:latest
docker tag apicurio/apicurito-ui apicurio/apicurito-ui:$RELEASE_VERSION
docker push apicurio/apicurito-ui:$RELEASE_VERSION


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

