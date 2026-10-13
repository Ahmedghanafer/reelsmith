import ReelsmithCore

/// The clip of middle tones: grey 128, 128, 128 on the left half and 64, 160, 96 on the right, stored
/// 1920 by 1080, so it stands whole and not scaled on the landscape canvas. A channel at 0 or 255 survives
/// a wrong curve, a middle tone does not. It is no seed clip: `writeTestClip` writes it for the test that asks.
func midToneClip() -> TestClip {
    TestClip(
        name: "mid-tone", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1200), framesPerSecond: 30,
        quarterTurns: 0, hasSound: false, left: RGB(r: 128, g: 128, b: 128), right: RGB(r: 64, g: 160, b: 96))
}
