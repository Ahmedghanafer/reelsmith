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

## Start a simulator run

The `macOS build` workflow is the simulator run: one run on a macOS runner with Xcode 26.6 that builds everything, runs the Engine tests and the UI tests in an iPhone simulator, and brings back the pictures, one recording and the test results. The repository is public, so runner time is free and a simulator run is repeated after each fix until it is green. It starts by hand only. It is started on `dev` when a group of changes is merged, and again after a fix:

```
gh workflow run "macOS build" --ref dev
gh workflow run "macOS build" --ref dev -f ipa=true
```

The second form also makes the unsigned build for the phone. Both run every UI test on one machine, which proves the whole app and takes the longest.

A change that touches a few test classes is checked sooner with a part run, started on its branch with the classes named, separated by spaces or commas:

```
gh workflow run "macOS build" --ref <branch> -f classes="TrimTests ToolsTests"
```

Layer 4 then runs only the named classes and the smoke set, chosen with `-only-testing` of `xcodebuild`. The smoke set is five tests named in one place, `SMOKE_TESTS` at the top of `.github/workflows/macos.yml`: the start with no seed of `StartTests`, the seed start of `HarnessTests`, the first frame of `PreviewTests`, the split and delete of `ToolsTests` and the export to the saved panel of `ExportPanelTests`. It is there so that a part run still shows that the app starts, shows a picture, takes an edit and saves a video. A part run proves the named classes and that much, and nothing about the other tests. A name that is no test class fails layer 4 before the warm start with a line that starts with `No UI test class is named`.

The whole suite runs sooner as a split run, which waits for the slowest of three machines:

```
gh workflow run "macOS build" --ref dev -f split=true
```

It starts three jobs, `build 1` to `build 3`, each with its own build, simulator, recording and artifacts. The test classes are read from the files of `UITests/` when the run starts, put in the order of their names, and dealt out one by one, so a new class is in a group without a change to the workflow. A file of `UITests/` with tests that does not hold exactly one test class, or a test class in a folder under `UITests/`, fails layer 4 of every group and of a part run, because that class would be in no group. The three groups together prove what the run on one machine proves. `classes` and `split` together fail layer 4. With `ipa=true` the first group makes the device build.

Every run says what it ran in one line that starts with `UI tests of this run:`, in the log of layer 4 and in the Summary: the classes asked for or the classes of the group, and the count of tests selected. After the tests a line `UI tests executed:` gives the count the test run reported. A part run or a group whose two counts differ fails layer 4, so a selection that ran nothing is never green.

To follow the run and read it:

```
gh run list --workflow "macOS build"
gh run watch <run id>
gh run view <run id> --log
```

The run creates one simulator, an iPhone 17 on the iOS 26.5 runtime, and works through seven layers in order. The setup step prints the simulators the runner image holds. With `-f image_simulator=true` the run uses the image's own iPhone 17 on that runtime in place of a new one, if there is one. Layer 3 prints `the boot, inside layer 3,` with the seconds of the boot and which simulator it was, and the line is in the Summary too:

1. `swift test` builds the package and runs its tests on macOS, the Engine tests among them. `REELSMITH_CLIP_DIR` is set, so the clip maker test leaves `blue.mov` and `red.mov` there.
2. The project is generated, and the app and the UI tests are built for testing.
3. The simulator boots, the built app is installed, the right to add to Photos is granted to the app, the two clips are put into the photo library, and the count of videos in the library is printed.
4. The app is started once on the seed `three-clips` and ended again (the warm start, below). Then the clock second is written to `recording-start.txt`, one recording of the simulator starts, and the UI tests run without a rebuild into a result bundle.
5. The screenshots and the mark files are exported from the result bundle under their attachment names, and each mark becomes one line of `recording-index.txt`. A name is made safe for the upload: each character the upload refuses (the double quote, colon, less than, greater than, vertical bar, asterisk, question mark, carriage return and line feed) becomes an underscore, and a name that is already taken gets a number before its ending, as in `<name>_2.txt`. The ending of a mark file is `.mark.txt` and that of any other name is what follows its last dot, so a taken name whose last dot is not an ending gets its number before that dot, as in `App UI hierarchy for com.ghanafer_2.reelsmith`.
6. The count of videos in the library is printed again.
7. Only with `ipa=true`: the device build without code signing, packed as `Reelsmith.ipa`.

Between layers 3 and 4 one step writes `tone.wav`, a tone of 3 seconds made with the runner's Python, into the storage of the simulator's Files app, which it finds by a search under the data folder of the device, and prints that folder, or that it found none, without making the run red.

The warm start of layer 4 is there because the first build of the editor after a clip was written can hold the app's main thread for more than 30 seconds on a hosted runner, and a UI query that waits that long fails its test. The seed `three-clips` needs every clip that any seed needs, so the warm start writes them all and builds the editor once, outside the recording and outside every test. The step reads the app's lines of the simulator log every few seconds until one holds `old picture`, which the app logs when the first item goes into the player, and then ends the app. It prints `The warm start:` with the seconds it took and whether that line was seen. It gives up after 180 seconds and the tests run all the same.

A layer is attempted whenever what it needs was built, also after an earlier layer failed. The last step, `Summary`, prints the result of every layer, the two counts and the seconds of each step, and the same text is on the run's page. A layer that reads `skipped` was not attempted. The run is red if any layer failed. A library that does not take the clips, or a count that cannot be read, is printed and does not make the run red. A UI test that runs longer than 600 seconds is ended and counts as failed. The run stops itself after 45 minutes. The export of the pictures taken until then is still attempted, and the uploads still happen.

## Fetch the artifacts

Every artifact is uploaded whether a layer failed or not, and is kept for 3 days. In PowerShell or Git Bash on this PC:

```
gh run download <run id> -n screens -D screens
gh run download <run id> -n recording -D recording
gh run download <run id> -n results -D results
gh run download <run id> -n ipa -D ipa
```

In a split run each group uploads its own three, named with the number of the group: `screens-1`, `recording-1`, `results-1`, and the same with 2 and 3.

- `screens` holds one picture per screenshot of the UI tests, named `<attachment name>.png`, and the mark files `<mark name>.mark.txt`. After a failed UI test it also holds a short `Screen Recording <date>.mp4` of that test, `Complete Issue Description.txt`, `App UI hierarchy for <bundle id>`, `UI Snapshot <date>`, and one debug description for each wait for an element that did not appear, all of which the test system adds by itself. A debug description is named ``Debug description for `"<identifier>" Any`.txt`` by the test system and is stored as ``Debug description for `_<identifier>_ Any`.txt``. Repeats of a name are numbered.
- `recording` holds `recording.mp4`, `recording-start.txt` and `recording-index.txt`. A line of the index is a mark's name, a space, and the seconds from the start of the recording to the mark, so that stretch is found by seeking to that second.
- `results` holds the result bundle `Reelsmith.xcresult` of the UI tests and `simulator-log.txt`, the lines the app wrote to the simulator's log during the warm start and the tests (a seed clip that could not be written says why there). The bundle opens only in Xcode. On this PC the log of the run says which test failed and why.
- `ipa` holds `Reelsmith.ipa`, the build for the phone, only when the run was started with `ipa=true`.

## Install on the iPhone with Sideloadly

This works: on 2026-10-12 an unsigned build of this project was installed with Sideloadly and a free Apple ID on an iPhone with iOS 26.6.2, and it opened. The steps:

1. Remove the Microsoft Store version of iTunes if it is installed (it does not work). Install iTunes for Windows from Apple's website and check that Apple Mobile Device Support is installed with it: it comes in the same installer, and a silent install of iTunes can leave it out. iCloud is not needed. Then install Sideloadly from sideloadly.io.
2. Connect the iPhone with a USB cable, unlock it and tap Trust.
3. Open Sideloadly, pick the phone, drag `Reelsmith.ipa` into the window, type the free Apple ID and press Start. Enter the Apple ID password when asked.
4. On the iPhone, open Settings, General, VPN & Device Management, tap the Apple ID and tap Trust.
5. On the iPhone, switch on Developer Mode under Settings, Privacy & Security (the switch appears only after the install), then restart the phone when asked.
6. Open Reelsmith. The start screen shows the name of the app, the two shapes and "New project".

A free Apple ID install stops working after 7 days. Repeat step 3 with the same Apple ID to renew it. A renewal installs over the app, which keeps its drafts. Never delete the app before a renewal: that removes every draft. Whether the drafts survive a renewal is on the list of what is judged on the phone.
