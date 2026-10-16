import Flutter
import Foundation

/// The dispatcher of the bridge: it answers every call of `app/pigeons/engine.dart` and sends its events.
/// Each call lives in the file of its area, `Launch.swift`, `Preview/`, `Media/` and `Output/`, as an
/// extension of this class. A call not built yet throws `EngineError.notBuilt`, which reaches Dart as a
/// `PlatformException` with the code `notBuilt` and never stops the app.
/// Inside the class a call of the Engine that shares the name of a call here, as `export` or `writeCover`,
/// is written `ReelsmithEngine.export`.
///
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
/// https://api.flutter.dev/ios-embedder/protocol_flutter_texture_registry-p.html
final class Engine: NSObject, EngineApi {
    /// Where the preview registers its texture.
    let textures: FlutterTextureRegistry
    /// Sends the events to Dart.
    let events = EngineEvents()

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
    }

    /// Makes the engine and sets it up as the handler of every call and the source of the events.
    static func register(with registrar: FlutterPluginRegistrar) {
        let engine = Engine(textures: registrar.textures())
        EngineApiSetup.setUp(binaryMessenger: registrar.messenger(), api: engine)
        EventsStreamHandler.register(with: registrar.messenger(), streamHandler: engine.events)
    }
}

/// The one event channel. Events sent while Dart does not listen are dropped. Send on the main thread.
final class EngineEvents: EventsStreamHandler {
    private var sink: PigeonEventSink<EngineEvent>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<EngineEvent>) {
        self.sink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        sink = nil
    }

    func send(_ event: EngineEvent) {
        sink?.success(event)
    }
}
