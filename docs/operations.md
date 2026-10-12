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

## Ask for a macOS run

The `macOS build` workflow builds the app, takes a screenshot in an iPhone simulator and packs an unsigned `Reelsmith.ipa`. macOS minutes are scarce, so it never runs on a push, only when asked for:

- A wave of merged stories is checked by one manual run on `dev` after the merges. A manual run works on any branch once the workflow file is on `dev`:

  ```
  gh workflow run "macOS build" --ref dev
  ```

- On a pull request: add the label `macos-run`. To run again, remove the label and add it back.

  ```
  gh pr edit <number> --add-label macos-run
  gh pr edit <number> --remove-label macos-run
  ```

The last step of the run prints how many seconds each main step took.

## Fetch the two artifacts

```
gh run list --workflow "macOS build"
gh run download <run id> -n screens -D screens
gh run download <run id> -n ipa -D ipa
```

`screens\first-screen.png` is the first screen in the simulator. `ipa\Reelsmith.ipa` is the build for the phone.

## Install on the iPhone with Sideloadly

Not yet proven on a phone. The steps as they should work:

1. Remove the Microsoft Store versions of iTunes and iCloud if they are installed (they do not work). Install iTunes and iCloud for Windows from Apple's website, then install Sideloadly from sideloadly.io.
2. Connect the iPhone with a USB cable, unlock it and tap Trust.
3. Open Sideloadly, pick the phone, drag `Reelsmith.ipa` into the window, type the free Apple ID and press Start. Enter the Apple ID password when asked.
4. On the iPhone, open Settings, General, VPN & Device Management, tap the Apple ID and tap Trust.
5. On the iPhone, switch on Developer Mode under Settings, Privacy & Security (the switch appears only after the install), then restart the phone when asked.
6. Open Reelsmith. Note the "First opened" date on the screen.

A free Apple ID install stops working after 7 days. Repeat step 3 with the same Apple ID to renew it. The "First opened" date should stay the same after a renewal: that shows saved data survives.
