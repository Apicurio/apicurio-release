#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing API Design Studio.  Many steps to follow."
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
git clone -b gh-pages git@github.com:apiman/apiman-studio.git www.designer.org
git clone git@github.com:apiman/apiman-studio.git
git clone ssh://58dcf5510c1e66fa6500017e@release-apistudio.rhcloud.com/~/git/release.git/ apistudio-release


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
rm -rf ~/.m2/repository/io/apiman
pushd .
cd apiman-studio
git checkout $BRANCH
mvn versions:set -DnewVersion=$RELEASE_VERSION
find . -name '*.versionsBackup' -exec rm -f {} \;
mvn clean install

git add .
git commit -m "Prepare for release v$RELEASE_VERSION"
git push origin $BRANCH
git tag -a -s -m "Tagging release v$RELEASE_VERSION" v$RELEASE_VERSION
git push origin v$RELEASE_VERSION


echo "---------------------------------------------------"
echo "Signing and Archiving the Quickstart ZIP"
echo "---------------------------------------------------"
mkdir -p releases
cp front-end/quickstart/target/api-design-studio-$RELEASE_VERSION-quickstart.zip releases/.
gpg --armor --detach-sign releases/api-design-studio-$RELEASE_VERSION-quickstart.zip


echo "---------------------------------------------------"
echo "Performing automated GitHub release."
echo "---------------------------------------------------"
java -jar tools/release/target/apiman-studio-tools-release-$RELEASE_VERSION.jar --release-name "$RELEASE_NAME" --release-tag $RELEASE_VERSION --previous-tag $PREVIOUS_RELEASE_VERSION --github-pat $GITHUB_AUTH_PAT --artifact ./releases/api-design-studio-$RELEASE_VERSION-quickstart.zip
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
echo " Updating Project Web Site"
echo "---------------------------------------------------"
pushd .
cd www.designer.org
sed -i "s/version:.*/version: $RELEASE_VERSION/g" _config.yml
git add .
git commit -m 'Updating version info due to release of version $RELEASE_VERSION.'
git push origin gh-pages
popd


echo "---------------------------------------------------"
echo " Pushing to OpenShift (release)"
echo "---------------------------------------------------"
pushd .
cd apistudio-release
git rm -rf diy/apache*
mkdir -p diy
cp ../apiman-studio/releases/api-design-studio-$RELEASE_VERSION-quickstart.zip ./diy/api-design-studio-$RELEASE_VERSION-quickstart.zip
cd diy
unzip api-design-studio-$RELEASE_VERSION-quickstart.zip
git add . --all
git commit -m "Pushing release $RELEASE_VERSION to OpenShift Origin"
git push origin master
popd


echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo ""
echo " Remaining release tasks:"
echo "   * Send a tweet!"
echo "---------------------------------------------------"

