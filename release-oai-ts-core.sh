#!/bin/sh

set -e

echo "---------------------------------------------------"
echo " Releasing oai-ts-core.  Many steps to follow."
echo " Please play along at home..."
echo "---------------------------------------------------"
echo ""
echo ""


echo "---------------------------------------------------"
echo " Tell me what version we're releasing!"
echo "---------------------------------------------------"
echo ""

RELEASE_VERSION=$1
BRANCH=$2

if [ "x$RELEASE_VERSION" = "x" ]
then
  read -p "Release Version: " RELEASE_VERSION
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
git clone git@github.com:apicurio/oai-ts-core.git
git clone git@github.com:apicurio/apicurio-studio.git


echo "---------------------------------------------------"
echo " Update version #s and validate builds"
echo "---------------------------------------------------"
pushd .
cd oai-ts-core
git checkout $BRANCH
sed -i "s/version.:.*/version\": \"$RELEASE_VERSION\",/g" package.json
yarn install
yarn test
yarn run package
git add package.json
git commit -m "Prepare for release $RELEASE_VERSION"
git push origin $BRANCH
git tag -a -s -m "Tagging release $RELEASE_VERSION" $RELEASE_VERSION
git push origin $RELEASE_VERSION
popd


echo "---------------------------------------------------"
echo " Create and release the package."
echo "---------------------------------------------------"
pushd .
cd oai-ts-core
npm publish ./dist
popd


echo "---------------------------------------------------"
echo " Deploy package to apicurio-studio (server)."
echo "---------------------------------------------------"
pushd .
cp oai-ts-core/dist/bundles/OAI.umd.js apicurio-studio/back-end/hub-core/src/main/resources/js-lib/OAI.umd.js
cd apicurio-studio
git add back-end/hub-core/src/main/resources/js-lib/OAI.umd.js
git commit -m "New release of oai-ts-core library."
git push origin master
popd

echo ""
echo ""
echo "---------------------------------------------------"
echo " ALL DONE!"
echo "---------------------------------------------------"

