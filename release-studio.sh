#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing Apicurio Studio.  Many steps to follow."
echo " Please play along at home..."
echo "---------------------------------------------------"
echo ""
echo ""


echo "---------------------------------------------------"
echo " Tell me what version we're releasing!"
echo "---------------------------------------------------"
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
git clone git@github.com:Apicurio/apicurio.github.io.git
git clone git@github.com:apicurio/apicurio-studio.git


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apicurio
pushd .
cd apicurio-studio
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
echo "Validating Apicurio Studio maven build"
mvn clean install


echo "Update version in package.json"
echo "---------------------------------------------------"
pushd .
cd front-end/studio
sed -i "s/version.:.*/version\": \"$RELEASE_VERSION\",/g" package.json
sed -i "s/.Final//g" package.json
rm -rf dist
yarn install
echo "Validating Apicurio Studio UI build"
yarn run package
popd


echo "Update version in OpenShift template(s)"
echo "---------------------------------------------------"
pushd .
cd distro/openshift
sed -i "s/latest-release/$RELEASE_VERSION/g" apicurio-template.yml
sed -i "s/latest-release/$RELEASE_VERSION/g" apicurio-standalone-template.yml
popd


echo "Commit changes and push to Git"
echo "---------------------------------------------------"
git add .
git commit -m "Prepare for release v$RELEASE_VERSION"
git push origin $BRANCH
git tag -a -s -m "Tagging release v$RELEASE_VERSION" v$RELEASE_VERSION
git push origin v$RELEASE_VERSION


echo "---------------------------------------------------"
echo "Releasing Apicurio UI into Maven Central"
echo "---------------------------------------------------"
mvn install -P release -Dgpg.passphrase=$GPG_PASSPHRASE


echo "---------------------------------------------------"
echo "Releasing Apicurio UI into NPM"
echo "---------------------------------------------------"
pushd .
cd front-end/studio
rm -rf dist
rm -rf node_modules
yarn install
yarn run package
npm publish ./dist
popd


echo "---------------------------------------------------"
echo "Signing and Archiving the Quickstart ZIP"
echo "---------------------------------------------------"
mkdir -p releases
cp distro/quickstart/target/apicurio-studio-$RELEASE_VERSION-quickstart.zip releases/.
gpg --armor --detach-sign releases/apicurio-studio-$RELEASE_VERSION-quickstart.zip


echo "---------------------------------------------------"
echo "Performing automated GitHub release."
echo "---------------------------------------------------"
java -jar tools/release/target/apicurio-studio-tools-release-$RELEASE_VERSION.jar --release-name "$RELEASE_NAME" --release-tag $RELEASE_VERSION --previous-tag $PREVIOUS_RELEASE_VERSION --github-pat $GITHUB_AUTH_PAT --artifact ./releases/apicurio-studio-$RELEASE_VERSION-quickstart.zip --output-directory ./tools/release/target
echo ""


echo "---------------------------------------------------"
echo "Creating Docker images."
echo "---------------------------------------------------"
docker build -t="apicurio/apicurio-studio-api" -t="apicurio/apicurio-studio-api:latest-release" -t="apicurio/apicurio-studio-api:$RELEASE_VERSION" --rm platforms/thorntail/api/
docker build -t="apicurio/apicurio-studio-ws" -t="apicurio/apicurio-studio-ws:latest-release" -t="apicurio/apicurio-studio-ws:$RELEASE_VERSION" --rm platforms/thorntail/ws/
docker build -t="apicurio/apicurio-studio-ui" -t="apicurio/apicurio-studio-ui:latest-release" -t="apicurio/apicurio-studio-ui:$RELEASE_VERSION" --rm platforms/thorntail/ui/


echo "---------------------------------------------------"
echo " Updating version #s for next snapshot version"
echo "---------------------------------------------------"
mvn versions:set -DnewVersion=$DEV_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
echo "Restoring 'latest-release' as the ImageStream version in the OpenShift template(s)"
pushd .
cd distro/openshift
sed -i "s/$RELEASE_VERSION/latest-release/g" apicurio-template.yml
sed -i "s/$RELEASE_VERSION/latest-release/g" apicurio-standalone-template.yml
popd
git add .
git commit -m "Update to next development version: $DEV_VERSION"
git push origin $BRANCH
popd


echo "---------------------------------------------------"
echo " Updating Project Web Site"
echo "---------------------------------------------------"
pushd .
cd apicurio.github.io
sed -i "s/version:.*/version: $RELEASE_VERSION/g" _config.yml
cp ../apicurio-studio/tools/release/target/20*.json ./_data/releases/.
cp ../apicurio-studio/tools/release/target/20*.json ./_data/latestRelease.json
git add .
git commit -m "Updating version info due to release of version $RELEASE_VERSION."
git push origin master
popd


echo "---------------------------------------------------"
echo "Pushing docker images."
echo "---------------------------------------------------"
docker push apicurio/apicurio-studio-api:latest
docker push apicurio/apicurio-studio-ws:latest
docker push apicurio/apicurio-studio-ui:latest

docker push apicurio/apicurio-studio-api:latest-release
docker push apicurio/apicurio-studio-ws:latest-release
docker push apicurio/apicurio-studio-ui:latest-release

docker push apicurio/apicurio-studio-api:$RELEASE_VERSION
docker push apicurio/apicurio-studio-ws:$RELEASE_VERSION
docker push apicurio/apicurio-studio-ui:$RELEASE_VERSION


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo ""
echo " Remaining release tasks:"
echo "   * Send a tweet!"
echo "---------------------------------------------------"

