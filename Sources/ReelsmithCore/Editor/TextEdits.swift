// The text actions, the blank rule and the nearest text.

/// What reduce calls for the case text. An action that names an unknown text returns the state unchanged,
/// and so does one with a size, a line spacing, a place or an angle that is not a finite number.
func reduceText(_ state: EditorState, _ action: TextAction) -> EditorState {
    var next = state
    switch action {
    case .add:
        guard state.canAddText else {
            return state
        }
        let id = TextID(state.project.nextTextID)
        let canvas = state.project.canvas
        next.project.texts.append(
            TextItem(
                id: id, string: "", span: .whole, x: Double(canvas.width) / 2, y: Double(canvas.height) / 2,
                rotation: 0, style: .standard))
        next.project.nextTextID += 1
        next.selectedText = id
        next.selection = nil
        next.isPlaying = false
        return next
    case .select(let id):
        guard state.project.text(id) != nil else {
            return state
        }
        next.selectedText = id
        next.selection = nil
        return next
    case .setString(let id, let string):
        guard let index = place(of: id, in: state) else {
            return state
        }
        next.project.texts[index].string = string
    case .setStyle(let id, let style):
        guard let index = place(of: id, in: state), style.size.isFinite, style.lineSpacing.isFinite else {
            return state
        }
        var held = style
        held.size = min(max(style.size, TextGeometry.minimumSize), TextGeometry.maximumSize)
        held.lineSpacing = min(max(style.lineSpacing, 0), 2)
        next.project.texts[index].style = held
    case .move(let id, let x, let y):
        guard let index = place(of: id, in: state), x.isFinite, y.isFinite else {
            return state
        }
        let canvas = state.project.canvas
        next.project.texts[index].x = min(max(x, 0), Double(canvas.width))
        next.project.texts[index].y = min(max(y, 0), Double(canvas.height))
    case .turn(let id, let angle):
        guard let index = place(of: id, in: state), angle.isFinite else {
            return state
        }
        var held = angle.truncatingRemainder(dividingBy: 360)
        if held > 180 {
            held -= 360
        } else if held <= -180 {
            held += 360
        }
        if held >= -3 && held <= 3 {
            held = 0
        }
        next.project.texts[index].rotation = held
    case .trimStart(let id, let amount):
        guard let index = place(of: id, in: state), let seen = state.project.range(of: id) else {
            return state
        }
        // A seen range shorter than the minimum gives a limit below zero, so the start moves back.
        let change = heldFrames(amount, from: Time.zero - seen.start, to: seen.duration - TextGeometry.minimumText)
        next.project.texts[index].span = span(
            from: seen.start + change, to: seen.start + seen.duration, in: state.project)
    case .trimEnd(let id, let amount):
        guard let index = place(of: id, in: state), let seen = state.project.range(of: id),
            seen.duration >= TextGeometry.minimumText
        else {
            return state
        }
        let end = seen.start + seen.duration
        let change = heldFrames(
            amount, from: end - state.project.duration, to: seen.duration - TextGeometry.minimumText)
        next.project.texts[index].span = span(from: seen.start, to: end - change, in: state.project)
    }
    next.isPlaying = false
    return next
}

/// The blank rule: a blank text exists only while it is selected. Called by reduce on every path.
func settleTexts(from before: EditorState, to after: EditorState) -> EditorState {
    // The text that was selected goes when it is blank and no longer selected. So does a text that is not
    // selected and was given a blank string.
    var next = after
    return next
}

extension Project {
    /// Among the texts that are not blank and whose range holds the time, the one whose centre is nearest
    /// in canvas pixels, the later of the list on a tie. Nil when there is none.
    public func text(nearestToX x: Double, y: Double, at time: Time) -> TextID? {
        var nearest: TextID?
        var least = Double.infinity
        for text in texts {
            guard !text.isBlank, let seen = range(of: text.id), seen.start <= time,
                time < seen.start + seen.duration
            else {
                continue
            }
            let distance = (text.x - x) * (text.x - x) + (text.y - y) * (text.y - y)
            if distance <= least {
                nearest = text.id
                least = distance
            }
        }
        return nearest
    }
}

private func place(of text: TextID, in state: EditorState) -> Int? {
    state.project.texts.firstIndex(where: { $0.id == text })
}

/// The amount held between the two limits, then rounded toward zero to whole frames.
private func heldFrames(_ amount: Time, from low: Time, to high: Time) -> Time {
    let held = min(max(amount, low), high)
    return Time(ticks: held.ticks / Time.frame.ticks * Time.frame.ticks)
}

/// Whole when the two ends are zero and the project length, a range otherwise.
private func span(from start: Time, to end: Time, in project: Project) -> TextSpan {
    if start == .zero && end == project.duration {
        return .whole
    }
    return .range(TextRange(start: start, duration: end - start))
}
