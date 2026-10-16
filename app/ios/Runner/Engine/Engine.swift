import Flutter
import Foundation

/// The dispatcher of the bridge: it answers every call of `app/pigeons/engine.dart` and sends its events.
/// Each call lives in the file of its area, `Launch.swift`, `Preview/`, `Media/` and `Output/`, as an
/// extension of this class, and the state of an area lives in the object of that area, declared in its file.
/// A call not built yet throws `EngineError.notBuilt`, which reaches Dart as a `PlatformException` with the
/// code `notBuilt` and never stops the app.
/// Inside the class a call of the Engine that shares the name of a call here, as `export` or `writeCover`,
/// is written `ReelsmithEngine.export`.
///
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
final class Engine: NSObject, EngineApi {
    /// The messenger, the textures and the view controller of the app, for the preview, a picker or an alert.
    let registrar: FlutterPluginRegistrar
    /// Sends the events to Dart.
    let events = EngineEvents()
    let preview = PreviewState()
    let media = MediaState()
    let output = OutputState()

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    /// Makes the engine and sets it up as the handler of every call and the source of the events.
    static func register(with registrar: FlutterPluginRegistrar) {
        let engine = Engine(registrar: registrar)
        EngineApiSetup.setUp(binaryMessenger: registrar.messenger(), api: engine)
        EventsStreamHandler.register(with: registrar.messenger(), streamHandler: engine.events)
    }
}

/// The one event channel. Events sent while Dart does not listen are dropped. `send` may be called on any
/// thread: it hands the event to the main thread, where the sink is set, read and cleared.
///
/// https://developer.apple.com/documentation/dispatch/dispatchqueue/async(group:qos:flags:execute:)
final class EngineEvents: EventsStreamHandler {
    private var sink: PigeonEventSink<EngineEvent>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<EngineEvent>) {
        self.sink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        sink = nil
    }

    func send(_ event: EngineEvent) {
        DispatchQueue.main.async {
            self.sink?.success(event)
        }
    }
}
