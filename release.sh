#! /bin/sh
set -eux

function commitChangedPoms() {
    POMS=$(find . -name pom.xml -not -path '*/target/*')
    if [ $(git status -s $POMS|grep -vc '^??') -gt 0 ]; then
        git commit -m "$1" $POMS
        git push
    fi
}

if [ $(git branch | grep '^*' | cut -c 2-) = 'master' ]; then
    echo 'Performing mainline release'

    # figure out version
    VERSION=$(mvn help:evaluate -Dexpression=project.version|grep '^[0-9]*\.[0-9]*\.[0-9]*-SNAPSHOT'|sed 's/-SNAPSHOT//')

    MAJOR=$(echo $VERSION|tr '.' ' '|awk '{print $1}')
    MINOR=$(echo $VERSION|tr '.' ' '|awk '{print $2}')
    PATCH=$(echo $VERSION|tr '.' ' '|awk '{print $3}')

    # create a mainline release branch
    BRANCH=$MAJOR.$MINOR.x
    mvn release:branch -B -DbranchName=$BRANCH -DreleaseVersion=$MAJOR.$MINOR.0 -DdevelopmentVersion=$MAJOR.$(expr $MINOR + 1).0-SNAPSHOT

    # update minor and patch versions on the branch
    git checkout $BRANCH
    mvn versions:use-latest-releases -DallowMajorUpdates=false
    commitChangedPoms 'Updated branch dependency minor versions for release'

    # perform release
    mvn release:prepare release:perform -B -DreleaseVersion=$MAJOR.$MINOR.0
    # commitChangedPoms 'Updated master project version after release'

    # updated master to latest snapshot versions
    git checkout master
    mvn versions:use-latest-versions -DallowMajorUpdates=false
    commitChangedPoms 'Updated master dependency minor versions after release'
else
    echo 'Performing interim release'

    # update patch versions
    mvn versions:use-latest-releases -DallowMajorUpdates=false -DallowMinorUpdates=false
    commitChangedPoms 'Updated branch dependency patch versions for release'

    mvn release:prepare release:perform -B
    # commitChangedPoms 'Updated branch project version after release'
fi