# Operations

Nothing is built on this PC. Tests and builds run on GitHub runners and are read with the `gh` command line.

## Run the tests

The `Tests` workflow runs `swift test` on a Linux runner for every pull request into `dev` and every push to `dev`. A branch gets a test run only once a pull request into `dev` is open. To read the result for a branch:

```
gh run list --workflow Tests --branch <branch>
gh run watch <run id>
gh run view <run id> --log
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
