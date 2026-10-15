import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const engine = MethodChannel('e25/engine');
const events = EventChannel('e25/events');

/// What the screen knows, kept outside the widgets so the integration test can read it.
class E25State extends ChangeNotifier {
  int? textureId;
  double seconds = 0;
  int frames = 0;
  String rgb = '';
  double time = 0;
  String seed = 'none';
  String exported = '';
  String error = '';
  double slider = 0;
  final List<double> seekMs = [];
  String refreshed = '';
  String swapped = '';
  double prepareMs = 0;
  bool probe = false;
  String exportPath = '';

  void changed() => notifyListeners();
}

final e25 = E25State();

void log(String line) => debugPrint('E25 $line');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // XCUITest reads the semantics tree, so it is built from the start.
  SemanticsBinding.instance.ensureSemantics();
  runApp(const E25App());
}

class E25App extends StatelessWidget {
  const E25App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'E25',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('ar')],
      home: E25Screen(),
    );
  }
}

class E25Screen extends StatefulWidget {
  const E25Screen({super.key});

  @override
  State<E25Screen> createState() => _E25ScreenState();
}

class _E25ScreenState extends State<E25Screen> {
  StreamSubscription<dynamic>? _sub;
  bool _seeking = false;
  double? _pending;

  @override
  void initState() {
    super.initState();
    e25.addListener(_redraw);
    _sub = events.receiveBroadcastStream().listen((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      if (map['type'] == 'frame') {
        e25.frames = map['count'] as int;
        e25.rgb = '${(map['r'] as num).round()} ${(map['g'] as num).round()} ${(map['b'] as num).round()}';
        if (e25.frames == 1) log('first frame rgb ${e25.rgb}');
      } else if (map['type'] == 'time') {
        e25.time = (map['seconds'] as num).toDouble();
      }
      e25.changed();
    });
    _start();
  }

  Future<void> _start() async {
    try {
      final args = List<String>.from(await engine.invokeMethod('launchArguments') as List);
      final i = args.indexOf('-seed');
      if (i >= 0 && i + 1 < args.length) e25.seed = args[i + 1];
      log('launch arguments $args');
      if (args.contains('-probe')) {
        e25.probe = true;
        e25.changed();
        return;
      }
      final ready = Map<String, dynamic>.from(await engine.invokeMethod('prepare') as Map);
      e25.textureId = ready['textureId'] as int;
      e25.seconds = (ready['seconds'] as num).toDouble();
      e25.prepareMs = (ready['ms'] as num).toDouble();
      log('prepared texture ${e25.textureId} seconds ${e25.seconds} in ${e25.prepareMs.round()} ms');
    } catch (e) {
      e25.error = '$e';
      log('error $e');
    }
    e25.changed();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    e25.removeListener(_redraw);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _export() async {
    e25.exported = 'exporting';
    e25.changed();
    try {
      final done = Map<String, dynamic>.from(await engine.invokeMethod('export') as Map);
      e25.exportPath = done['path'] as String;
      e25.exported =
          'export done ${done['bytes']} bytes ${(done['seconds'] as num).toStringAsFixed(2)} s in ${(done['ms'] as num).round()} ms';
    } catch (e) {
      e25.exported = 'export failed $e';
    }
    log(e25.exported);
    e25.changed();
  }

  Future<void> _seek(double value) async {
    e25.slider = value;
    e25.changed();
    if (_seeking) {
      _pending = value;
      return;
    }
    _seeking = true;
    double? next = value;
    while (next != null) {
      _pending = null;
      final done = Map<String, dynamic>.from(await engine.invokeMethod('seek', {'seconds': next}) as Map);
      e25.seekMs.add((done['ms'] as num).toDouble());
      next = _pending;
    }
    _seeking = false;
    e25.changed();
  }

  Future<void> _refresh() async {
    try {
      final r = Map<String, dynamic>.from(await engine.invokeMethod('refresh') as Map);
      e25.refreshed =
          'refresh luma ${(r['beforeLuma'] as num).round()} to ${(r['afterLuma'] as num).round()} frames ${r['framesBetween']}, nudged luma ${(r['nudgedLuma'] as num).round()} frames ${r['nudgedFrames']} in ${(r['ms'] as num).round()} ms';
    } catch (e) {
      e25.refreshed = 'refresh failed $e';
    }
    log(e25.refreshed);
    e25.changed();
  }

  Future<void> _swap() async {
    try {
      final r = Map<String, dynamic>.from(await engine.invokeMethod('swap') as Map);
      e25.swapped =
          'swap buffers ${r['buffers']} black ${r['black']} min luma ${(r['minLuma'] as num).round()} last g ${(r['lastG'] as num).round()} in ${(r['ms'] as num).round()} ms';
    } catch (e) {
      e25.swapped = 'swap failed $e';
    }
    log(e25.swapped);
    e25.changed();
  }

  Widget _text(String id, String text) => Semantics(
        identifier: id,
        container: true,
        label: text,
        excludeSemantics: true,
        child: Text(text, key: ValueKey(id), style: const TextStyle(fontSize: 13)),
      );

  Widget _button(String id, String label, VoidCallback onPressed) => Semantics(
        identifier: id,
        container: true,
        child: ElevatedButton(key: ValueKey(id), onPressed: onPressed, child: Text(label)),
      );

  @override
  Widget build(BuildContext context) {
    if (e25.probe) return const ProbeScreen();
    final direction = Directionality.of(context) == TextDirection.rtl ? 'rtl' : 'ltr';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final seekMean = e25.seekMs.isEmpty ? 0 : e25.seekMs.reduce((a, b) => a + b) / e25.seekMs.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 280,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      color: Colors.black,
                      child: e25.textureId == null
                          ? null
                          : Texture(key: const ValueKey('e25.texture'), textureId: e25.textureId!),
                    ),
                  ),
                ),
              ),
              _text('e25.frames', 'frames ${e25.frames} rgb ${e25.rgb}'),
              _text('e25.time', 'time ${e25.time.toStringAsFixed(2)}'),
              Row(children: [
                Expanded(child: _button('e25.play', 'Play', () => engine.invokeMethod('play'))),
                const SizedBox(width: 8),
                Expanded(child: _button('e25.export', 'Export', _export)),
              ]),
              _text('e25.exported', e25.exported.isEmpty ? 'no export' : e25.exported),
              _text('e25.seed', 'seed ${e25.seed}'),
              _text('e25.dir', 'dir $direction locale $locale'),
              Semantics(
                identifier: 'e25.selected',
                container: true,
                selected: true,
                label: 'chosen',
                excludeSemantics: true,
                child: const Text('chosen', style: TextStyle(fontSize: 13)),
              ),
              Semantics(
                identifier: 'e25.slider',
                container: true,
                child: Slider(
                  key: const ValueKey('e25.slider'),
                  value: e25.slider.clamp(0, e25.seconds > 0 ? e25.seconds : 1),
                  max: e25.seconds > 0 ? e25.seconds : 1,
                  onChanged: _seek,
                ),
              ),
              _text('e25.sliderValue',
                  'slider ${e25.slider.toStringAsFixed(2)} seeks ${e25.seekMs.length} mean ${seekMean.toStringAsFixed(1)} ms'),
              Row(children: [
                Expanded(child: _button('e25.refresh', 'Refresh', _refresh)),
                const SizedBox(width: 8),
                Expanded(child: _button('e25.swap', 'Swap', _swap)),
              ]),
              _text('e25.refreshed', e25.refreshed.isEmpty ? 'no refresh' : e25.refreshed),
              _text('e25.swapped', e25.swapped.isEmpty ? 'no swap' : e25.swapped),
              if (e25.error.isNotEmpty) _text('e25.error', e25.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// The probes of XCUITest against Flutter widgets, shown when the app is launched with -probe.
class ProbeScreen extends StatefulWidget {
  const ProbeScreen({super.key});

  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen> {
  final _field = TextEditingController();
  final _region = GlobalKey();
  String _gesture = 'scale 1.00 rotation 0.00';
  double _baseScale = 1;
  String _picked = 'nothing picked';
  String _regionSize = 'region unknown';
  String _alert = 'no alert';
  double _slider = 0.5;

  @override
  void initState() {
    super.initState();
    _field.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _region.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.localToGlobal(Offset.zero);
    setState(() {
      _regionSize =
          'region ${box.size.width.round()}x${box.size.height.round()} at ${at.dx.round()},${at.dy.round()}';
    });
    log(_regionSize);
  }

  Future<void> _pick() async {
    try {
      final r = Map<String, dynamic>.from(await engine.invokeMethod('pick') as Map);
      _picked = 'picked ${r['count']} ${r['type']}';
    } catch (e) {
      _picked = 'pick failed $e';
    }
    log(_picked);
    setState(() {});
  }

  Future<void> _showAlert() async {
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Probe alert'),
        content: const Text('Tap OK'),
        actions: [
          Semantics(
            identifier: 'p.alertOk',
            container: true,
            child: TextButton(onPressed: () => Navigator.of(context).pop('ok'), child: const Text('OK')),
          ),
        ],
      ),
    );
    setState(() => _alert = 'alert closed $answer');
  }

  Widget _text(String id, String text) => Semantics(
        identifier: id,
        container: true,
        label: text,
        excludeSemantics: true,
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 12);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                identifier: 'p.value',
                container: true,
                label: 'meter',
                value: '42 percent',
                excludeSemantics: true,
                child: const Text('meter', style: small),
              ),
              Semantics(
                identifier: 'p.field',
                child: TextField(controller: _field, decoration: const InputDecoration(hintText: 'type here')),
              ),
              _text('p.echo', 'echo ${_field.text}'),
              Semantics(
                identifier: 'p.gestureArea',
                container: true,
                child: GestureDetector(
                  onScaleStart: (_) => _baseScale = 1,
                  onScaleUpdate: (d) => setState(() {
                    _gesture = 'scale ${(d.scale * _baseScale).toStringAsFixed(2)} rotation ${d.rotation.toStringAsFixed(2)}';
                  }),
                  child: Container(height: 140, color: Colors.teal.shade200),
                ),
              ),
              _text('p.gesture', _gesture),
              Row(children: [
                Expanded(
                  child: Semantics(
                    identifier: 'p.pick',
                    container: true,
                    child: ElevatedButton(onPressed: _pick, child: const Text('Pick')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    identifier: 'p.alert',
                    child: ElevatedButton(onPressed: _showAlert, child: const Text('Alert')),
                  ),
                ),
              ]),
              _text('p.picked', _picked),
              _text('p.alertResult', _alert),
              Semantics(
                identifier: 'p.region',
                container: true,
                child: SizedBox(
                  key: _region,
                  height: 80,
                  child: const Column(children: [Text('first', style: small), Text('second', style: small)]),
                ),
              ),
              _text('p.regionSize', _regionSize),
              Semantics(
                identifier: 'p.slider',
                child: Slider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
              ),
              _text('p.sliderValue', 'slider ${_slider.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }
}
