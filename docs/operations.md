# Operations

Nothing is built on this PC. Tests and builds run on GitHub runners and are read with the `gh` command line.

## Run the tests

The `Tests` workflow runs `swift test` on a Linux runner for every pull request into `dev` and every push to `dev`. A branch gets a test run only once a pull request into `dev` is open. To read the result for a branch:

```
gh run list --workflow Tests --branch <branch>
gh run watch <run id>
gh run view <run id> --log
```

## Ask for a compile check

The `Compile check` workflow compiles a pull request's Apple code on a macOS runner with Xcode 26.6. It generates the project, runs `swift test` for the package (the Engine tests run here, with no simulator), builds the app and the UI tests for a simulator with `xcodebuild build-for-testing`, and runs `plutil -lint` over the word files. Every part runs even when an earlier one failed, and the check is red if any part is. No simulator is booted and no UI test runs. It stops itself after 15 minutes.

Put the label `compile` on the pull request to start it. A new commit does not start a run. To run it again after a fix, take the label off and put it back:

```
gh pr edit <number> --remove-label compile
gh pr edit <number> --add-label compile
```

A pull request with a merge conflict gets no run at all: rebase it first.

The result shows among the checks of the pull request, where `gh pr checks` prints it under the job name `compile`, and in the run list:

```
gh pr checks <number>
gh run list --workflow "Compile check" --branch <branch>
gh run view <run id> --log
```

The workflow starts on every label and skips its job for any label but `compile`. So another label put on the pull request afterwards starts a skipped run, and that skipped run takes the place of the result in `gh pr checks`. The result that counts is the newest run in `gh run list --workflow "Compile check" --branch <branch>` that was not skipped and whose head is the head of the pull request.

Once the workflow file is on `dev` it can also be started by hand on any branch:

```
gh workflow run "Compile check" --ref <branch>
```

## Start a wave run

The `macOS build` workflow is the wave run: one run on a macOS runner with Xcode 26.6 that builds everything, runs the Engine tests and the UI tests in an iPhone simulator, and brings back the pictures, one recording and the test results. The repository is public, so runner time is free and a wave run is repeated after each fix until it is green. It starts by hand only. It is started on `dev` when a group of changes is merged, and again after a fix:

```
gh workflow run "macOS build" --ref dev
gh workflow run "macOS build" --ref dev -f ipa=true
```

The second form also makes the unsigned build for the phone. To follow the run and read it:

```
gh run list --workflow "macOS build"
gh run watch <run id>
gh run view <run id> --log
```

The run creates one simulator, an iPhone 17 on the iOS 26.5 runtime, and works through seven layers in order:

1. `swift test` builds the package and runs its tests on macOS, the Engine tests among them. `REELSMITH_CLIP_DIR` is set, so the clip maker test leaves `blue.mov` and `red.mov` there.
2. The project is generated, and the app and the UI tests are built for testing.
3. The simulator boots, the built app is installed, the right to add to Photos is granted to the app, the two clips are put into the photo library, and the count of videos in the library is printed.
4. The clock second is written to `recording-start.txt`, one recording of the simulator starts, and the UI tests run without a rebuild into a result bundle.
5. The screenshots and the mark files are exported from the result bundle under their attachment names, and each mark becomes one line of `recording-index.txt`.
6. The count of videos in the library is printed again.
7. Only with `ipa=true`: the device build without code signing, packed as `Reelsmith.ipa`.

A layer is attempted whenever what it needs was built, also after an earlier layer failed. The last step, `Summary`, prints the result of every layer, the two counts and the seconds of each step, and the same text is on the run's page. A layer that reads `skipped` was not attempted. The run is red if any layer failed. A library that does not take the clips, or a count that cannot be read, is printed and does not make the run red. A UI test that runs longer than 300 seconds is ended and counts as failed. The run stops itself after 30 minutes, and the pictures taken until then are still exported and uploaded.

## Fetch the artifacts

Every artifact is uploaded whether a layer failed or not, and is kept for 3 days. In PowerShell or Git Bash on this PC:

```
gh run download <run id> -n screens -D screens
gh run download <run id> -n recording -D recording
gh run download <run id> -n results -D results
gh run download <run id> -n ipa -D ipa
```

- `screens` holds one picture per screenshot of the UI tests, named `<attachment name>.png`, and the mark files `<mark name>.mark.txt`.
- `recording` holds `recording.mp4`, `recording-start.txt` and `recording-index.txt`. A line of the index is a mark's name, a space, and the seconds from the start of the recording to the mark, so that stretch is found by seeking to that second.
- `results` holds the result bundle `Reelsmith.xcresult` of the UI tests and `simulator-log.txt`, the lines the app wrote to the simulator's log during the tests (a seed clip that could not be written says why there). The bundle opens only in Xcode. On this PC the log of the run says which test failed and why.
- `ipa` holds `Reelsmith.ipa`, the build for the phone, only when the run was started with `ipa=true`.

## Install on the iPhone with Sideloadly

This works: on 2026-10-12 an unsigned build of this project was installed with Sideloadly and a free Apple ID on an iPhone with iOS 26.6.2, and it opened. The steps:

1. Remove the Microsoft Store versions of iTunes and iCloud if they are installed (they do not work). Install iTunes and iCloud for Windows from Apple's website, then install Sideloadly from sideloadly.io.
2. Connect the iPhone with a USB cable, unlock it and tap Trust.
3. Open Sideloadly, pick the phone, drag `Reelsmith.ipa` into the window, type the free Apple ID and press Start. Enter the Apple ID password when asked.
4. On the iPhone, open Settings, General, VPN & Device Management, tap the Apple ID and tap Trust.
5. On the iPhone, switch on Developer Mode under Settings, Privacy & Security (the switch appears only after the install), then restart the phone when asked.
6. Open Reelsmith. Note the "First opened" date on the screen.

A free Apple ID install stops working after 7 days. Repeat step 3 with the same Apple ID to renew it. The "First opened" date should stay the same after a renewal: that shows saved data survives.
