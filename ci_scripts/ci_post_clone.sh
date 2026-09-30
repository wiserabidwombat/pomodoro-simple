#!/bin/sh
# Xcode Cloud runs this automatically right after it clones the repo, before
# it looks for the project. Pomodoro.xcodeproj is generated from project.yml
# by XcodeGen and is git-ignored, so the fresh clone doesn't have it; without
# this script every Xcode Cloud build fails with "Project Pomodoro.xcodeproj
# does not exist at the root of the repository".
#
# Xcode Cloud's build machines come with Homebrew. The file must be
# executable (git mode 100755) and live in ci_scripts/ next to the project.
set -e

# Skip Homebrew's own self-update; it only slows the build down.
export HOMEBREW_NO_AUTO_UPDATE=1
brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
