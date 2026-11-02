import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../data/text_reader.dart';
import '../../models/expense.dart';
import '../../state/expense_store.dart';
import '../../state/scan_parser.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';

/// "Scan to fill": point the camera at a receipt or a written list, check
/// what was read, and fill today's bag with it. Pops with the saved day.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.animation,
    required this.onTypeInstead,
  });

  final Animation<double> animation;

  /// "Type it instead": opens the Bazar Diary once this screen has closed.
  final VoidCallback onTypeInstead;

  static Route<DateTime?> route({required VoidCallback onTypeInstead}) =>
      LiquidOverlayRoute<DateTime?>(
        curve: Motion.smooth,
        builder: (context, animation) =>
            ScanScreen(animation: animation, onTypeInstead: onTypeInstead),
      );

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Stage { camera, scanning, review }

/// The camera chrome is always over a dark picture, in either theme.
abstract final class _Chrome {
  static const _tint = Color.fromRGBO(40, 40, 46, 0.45);
  static const _tintStrong = Color.fromRGBO(40, 40, 46, 0.5);
  static const _edge = Color.fromRGBO(255, 255, 255, 0.18);
  static const _rim = CssShadow.inset(
    dy: 1,
    color: Color.fromRGBO(255, 255, 255, 0.18),
  );

  static const roundButton = GlassStyle(
    radius: 22,
    color: _tint,
    blur: 20,
    saturation: 1.6,
    borderColor: _edge,
    shadows: [_rim],
  );
  static const title = GlassStyle(
    radius: 18,
    color: _tint,
    blur: 20,
    saturation: 1.6,
    borderColor: _edge,
  );
  static const modeTrack = GlassStyle(
    radius: 20,
    color: _tintStrong,
    blur: 20,
    saturation: 1.6,
    borderColor: Color.fromRGBO(255, 255, 255, 0.16),
  );
  static const sideButton = GlassStyle(
    radius: 16,
    color: _tintStrong,
    blur: 20,
    borderColor: _edge,
  );

  static const frame = Color.fromRGBO(255, 255, 255, 0.92);
  static const scanBlue = Color(0xFF6CB8FF);
  static const flashOn = Color(0xFFFFD60A);
  static const hint = Color.fromRGBO(255, 255, 255, 0.88);
  static const modeOff = Color.fromRGBO(255, 255, 255, 0.85);
  static const modeOn = Color.fromRGBO(255, 255, 255, 0.92);
  static const shutterRing = Color.fromRGBO(255, 255, 255, 0.95);
  static const reviewScrim = Color.fromRGBO(0, 0, 0, 0.38);
}

/// One read line on the review sheet.
class _ReviewItem {
  _ReviewItem(ScannedItem item)
    : name = item.name,
      unsure = item.unsure,
      price = TextEditingController(
        text: item.price == null ? '' : editableAmount(item.price!),
      );

  final String name;
  final TextEditingController price;
  bool unsure;
  bool on = true;

  double get value => double.tryParse(price.text.trim()) ?? 0;
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // The design's frame: 36px in from each side, 436 tall, its top 132px
  // down a canvas with a 47px status bar.
  static const _frameInset = 36.0;
  static const _frameTop = 132.0 - 47;
  static const _frameHeight = 436.0;

  /// From the frame's bottom to the screen's, on the 844px design canvas
  /// (whose home indicator takes 34).
  static const _belowFrame = 844.0 - 568 - 34;

  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  late final _sheet = AnimationController(
    vsync: this,
    duration: Motion.smooth.duration,
    reverseDuration: Motion.dismissDuration,
  );
  late final _sheetCurve = CurvedAnimation(
    parent: _sheet,
    curve: Motion.smooth,
    reverseCurve: Motion.dismiss,
  );

  CameraController? _camera;
  bool _cameraFailed = false;
  bool _flash = false;
  ScanMode _mode = ScanMode.receipt;
  _Stage _stage = _Stage.camera;

  /// The photo being read, decoded and frozen behind the frame.
  ui.Image? _photo;
  ScanResult? _result;
  List<_ReviewItem> _items = [];

  /// Replaces the framing hint after a failed read.
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _sweep.dispose();
    _sheetCurve.dispose();
    _sheet.dispose();
    _photo?.dispose();
    for (final item in _items) {
      item.price.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is handed back to the system while the app is away.
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _camera = null;
      camera.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (back.isEmpty) throw CameraException('none', 'No back camera');
      final camera = CameraController(
        back.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (_flash) await camera.setFlashMode(FlashMode.torch);
      if (!mounted) {
        camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraFailed = false;
      });
    } on CameraException {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  void _close() => Navigator.of(context).maybePop();

  void _typeInstead() {
    Navigator.of(context).pop();
    widget.onTypeInstead();
  }

  void _toggleFlash() {
    setState(() => _flash = !_flash);
    _camera?.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
  }

  void _pickMode(ScanMode mode) {
    if (_stage != _Stage.camera || mode == _mode) return;
    setState(() {
      _mode = mode;
      _notice = null;
    });
  }

  Future<void> _shoot() async {
    if (_stage != _Stage.camera) return;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      Haptics.play(HapticKind.warning);
      setState(() => _notice = tr.noCamera);
      return;
    }
    if (camera.value.isTakingPicture) return;
    try {
      final shot = await camera.takePicture();
      await _read(shot.path);
    } on CameraException {
      Haptics.play(HapticKind.warning);
      if (mounted) setState(() => _notice = tr.noCamera);
    }
  }

  Future<void> _choosePhoto() async {
    if (_stage != _Stage.camera) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) await _read(picked.path);
  }

  /// Freezes [path] behind the frame, sweeps it while the text is read,
  /// then opens the review sheet (or explains why nothing was found).
  Future<void> _read(String path) async {
    setState(() {
      _stage = _Stage.scanning;
      _result = null;
      _notice = null;
    });

    var done = false;
    final reading = TextReader.read(path)
        .then((lines) => ScanParser.parse(lines, _mode))
        .catchError((Object _) => const ScanResult(items: []))
        .whenComplete(() => done = true);
    // Decode the photo first, so the sweep always passes over it.
    final photo = await _decode(path);
    if (!mounted) {
      photo?.dispose();
      return;
    }
    _showPhoto(photo);
    // One full sweep always plays, so the read feels deliberate; slow
    // reads keep sweeping until they finish.
    await _sweep.forward(from: 0);
    if (!done) {
      unawaited(_sweep.repeat());
      await reading;
      _sweep.stop();
      _sweep.value = 1;
    }
    final result = await reading;
    if (!mounted) return;

    if (result.items.isEmpty) {
      Haptics.play(HapticKind.warning);
      _showPhoto(null);
      setState(() {
        _stage = _Stage.camera;
        _notice = tr.noItemsFound;
      });
      return;
    }
    Haptics.play(HapticKind.success);
    for (final item in _items) {
      item.price.dispose();
    }
    setState(() {
      _result = result;
      _items = [for (final item in result.items) _ReviewItem(item)];
      _stage = _Stage.review;
    });
    _sheet.forward(from: 0);
  }

  static Future<ui.Image?> _decode(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } on Object {
      return null;
    }
  }

  void _showPhoto(ui.Image? photo) {
    final old = _photo;
    setState(() => _photo = photo);
    // The old picture may still be on screen until the next frame.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  Future<void> _retake() async {
    FocusScope.of(context).unfocus();
    await _sheet.reverse();
    if (!mounted) return;
    _showPhoto(null);
    setState(() {
      _stage = _Stage.camera;
      _result = null;
    });
    _sweep.value = 0;
  }

  void _fillBag() {
    final items = [
      for (final item in _items)
        if (item.on && item.value > 0)
          Expense(name: item.name, amount: item.value),
    ];
    if (items.isEmpty) {
      Haptics.play(HapticKind.warning);
      return;
    }
    final today = dateOnly(DateTime.now());
    context.read<ExpenseStore>().saveDay(date: today, items: items);
    Haptics.play(HapticKind.success);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(today);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final bottomInset = math.max(mq.padding.bottom, 20.0);
    final frameTop = safeTop + _frameTop;
    final frameHeight = math.min(
      _frameHeight,
      mq.size.height - frameTop - _belowFrame - bottomInset,
    );
    final frame = Rect.fromLTWH(
      _frameInset,
      frameTop,
      mq.size.width - _frameInset * 2,
      frameHeight,
    );
    final scanning = _stage == _Stage.scanning;
    final review = _stage == _Stage.review;

    final screen = Stack(
      children: [
        const Positioned.fill(child: _Backdrop()),
        if (_camera case final camera?)
          Positioned.fill(child: _Preview(camera: camera)),
        if (_photo case final photo?)
          Positioned.fill(
            child: RawImage(image: photo, fit: BoxFit.cover),
          ),
        if (_result != null && _photo != null)
          Positioned.fill(
            child: _Highlights(
              items: _result!.items,
              photoSize: Size(
                _photo!.width.toDouble(),
                _photo!.height.toDouble(),
              ),
              sweep: _sweep,
              frame: frame,
              settled: review,
            ),
          ),
        Positioned.fromRect(
          rect: frame,
          child: IgnorePointer(
            child: _Frame(sweep: _sweep, scanning: scanning),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: safeTop + 11,
          child: _TopBar(flash: _flash, onClose: _close, onFlash: _toggleFlash),
        ),
        if (!review) ...[
          Positioned(
            left: 24,
            right: 24,
            top: frame.bottom + 22,
            child: _Hint(
              text: scanning
                  ? tr.readingItems
                  : _notice ??
                        (_cameraFailed
                            ? tr.noCamera
                            : _mode == ScanMode.receipt
                            ? tr.fitReceipt
                            : tr.fitList),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: frame.bottom + 62,
            child: Center(
              child: _ModeSwitch(
                mode: _mode,
                enabled: !scanning,
                onPick: _pickMode,
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: bottomInset + 10,
            child: _Controls(
              scanning: scanning,
              onPhoto: _choosePhoto,
              onShoot: _shoot,
              onType: _typeInstead,
            ),
          ),
        ],
        if (review) ...[
          Positioned.fill(
            child: FadeTransition(
              opacity: _sheetCurve,
              child: const ColoredBox(color: _Chrome.reviewScrim),
            ),
          ),
          _ReviewSheet(
            animation: _sheetCurve,
            items: _items,
            source: _mode == ScanMode.receipt
                ? tr.fromReceipt(_result?.store)
                : tr.fromWrittenList,
            onChanged: () => setState(() {}),
            onRetake: _retake,
            onFill: _fillBag,
          ),
        ],
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AnimatedBuilder(
        animation: widget.animation,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: tr.scanToFill,
          child: ClipRect(child: screen),
        ),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - widget.animation.value) * mq.size.height),
          child: child,
        ),
      ),
    );
  }
}

/// The design's dark room, shown until (or instead of) the live camera.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, size) {
        // CSS `radial-gradient(120% 80% at 50% 40%, …)`: an ellipse 1.2
        // widths across and 0.8 heights tall.
        final rx = size.maxWidth * 1.2;
        final ry = size.maxHeight * 0.8;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: ry / size.biggest.shortestSide,
              transform: _StretchX(rx / ry),
              colors: const [
                Color(0xFF3A3631),
                Color(0xFF1C1A18),
                Color(0xFF0B0B0C),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _StretchX extends GradientTransform {
  const _StretchX(this.factor);

  final double factor;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    final cy = bounds.top + bounds.height * 0.4;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(factor, 1, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

/// The live camera, filling the screen like `object-fit: cover`.
class _Preview extends StatelessWidget {
  const _Preview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final size = camera.value.previewSize;
    if (size == null) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // The sensor reports landscape; the app is portrait.
          width: size.height,
          height: size.width,
          child: camera.buildPreview(),
        ),
      ),
    );
  }
}

/// The blue wash over each line the sweep has read.
class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.items,
    required this.photoSize,
    required this.sweep,
    required this.frame,
    required this.settled,
  });

  final List<ScannedItem> items;
  final Size photoSize;
  final Animation<double> sweep;
  final Rect frame;

  /// Reading is over: every line shows.
  final bool settled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final view = box.biggest;
        final scale = math.max(
          view.width / photoSize.width,
          view.height / photoSize.height,
        );
        final drawn = photoSize * scale;
        final origin = Offset(
          (view.width - drawn.width) / 2,
          (view.height - drawn.height) / 2,
        );
        Rect onScreen(Rect r) => Rect.fromLTRB(
          origin.dx + r.left * drawn.width,
          origin.dy + r.top * drawn.height,
          origin.dx + r.right * drawn.width,
          origin.dy + r.bottom * drawn.height,
        );

        return AnimatedBuilder(
          animation: sweep,
          builder: (context, _) {
            final line = frame.top + sweep.value * frame.height;
            return Stack(
              children: [
                for (final item in items)
                  () {
                    final r = onScreen(item.box);
                    final seen = settled || line > r.center.dy;
                    // The design pads each line 6px across and 2px down.
                    return Positioned(
                      left: r.left - 6,
                      top: r.top - 2,
                      width: r.width + 12,
                      height: r.height + 4,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.ease,
                        decoration: BoxDecoration(
                          color: seen
                              ? const Color.fromRGBO(10, 132, 255, 0.14)
                              : const Color.fromRGBO(10, 132, 255, 0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignOutside,
                            color: seen
                                ? const Color.fromRGBO(10, 132, 255, 0.55)
                                : const Color.fromRGBO(10, 132, 255, 0),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            );
          },
        );
      },
    );
  }
}

/// Four rounded corner brackets and, while reading, the sweeping line.
class _Frame extends StatelessWidget {
  const _Frame({required this.sweep, required this.scanning});

  final Animation<double> sweep;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: scanning ? _Chrome.scanBlue : _Chrome.frame),
      duration: const Duration(milliseconds: 250),
      builder: (context, color, _) => CustomPaint(
        painter: _CornersPainter(color!),
        child: scanning
            ? AnimatedBuilder(
                animation: sweep,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, box) {
                    final top = (sweep.value * box.maxHeight).roundToDouble();
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 10,
                          right: 10,
                          top: top - 70,
                          height: 70,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.fromRGBO(10, 132, 255, 0),
                                  Color.fromRGBO(10, 132, 255, 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          top: top,
                          height: 3,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: _Chrome.scanBlue,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 12,
                                  spreadRadius: 3,
                                  color: Color.fromRGBO(10, 132, 255, 0.8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// Each corner is the design's 38px box with a 4px border on two sides
/// and an 18px outer radius: drawn along the border's centre line.
class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color);

  final Color color;

  static const _arm = 38.0;
  static const _width = 4.0;
  static const _radius = 18.0 - _width / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    const h = _width / 2;
    Path corner() => Path()
      ..moveTo(h, _arm)
      ..lineTo(h, h + _radius)
      ..arcToPoint(
        const Offset(h + _radius, h),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_arm, h);
    for (final (dx, dy, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      canvas
        ..save()
        ..translate(dx, dy)
        ..scale(sx, sy)
        ..drawPath(corner(), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flash,
    required this.onClose,
    required this.onFlash,
  });

  final bool flash;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LiquidPressable(
          onTap: onClose,
          haptic: HapticKind.light,
          pressedScale: 0.9,
          borderRadius: 23,
          semanticLabel: tr.closeScanner,
          child: const LiquidBox(
            style: _Chrome.roundButton,
            width: 44,
            height: 44,
            child: Center(
              child: LineIcon(
                LineGlyph.close,
                size: 18,
                strokeWidth: 2.4,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        LiquidBox(
          style: _Chrome.title,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Semantics(
              header: true,
              child: Text(
                tr.scanToFill,
                style: AppText.subheadBold.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ),
        LiquidPressable(
          onTap: onFlash,
          haptic: HapticKind.light,
          pressedScale: 0.9,
          borderRadius: 22,
          semanticLabel: tr.flash,
          selected: flash,
          // A <button> is border-box: 44 across including its rim.
          child: LiquidBox(
            style: _Chrome.roundButton,
            width: 42,
            height: 42,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.snappy.duration,
                child: LineIcon(
                  LineGlyph.flash,
                  key: ValueKey(flash),
                  size: 18,
                  color: flash ? _Chrome.flashOn : AppColors.white,
                  fill: flash ? _Chrome.flashOn : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _Chrome.hint,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 6,
                color: Color.fromRGBO(0, 0, 0, 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onPick,
  });

  final ScanMode mode;
  final bool enabled;
  final ValueChanged<ScanMode> onPick;

  @override
  Widget build(BuildContext context) {
    Widget option(ScanMode value, String label) {
      final on = value == mode;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: enabled ? () => onPick(value) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  if (!on) Haptics.play(HapticKind.selection);
                  onPick(value);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? _Chrome.modeOn : const Color(0x00FFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppText.base.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? const Color(0xFF1C1C1E) : _Chrome.modeOff,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: tr.whatAreYouScanning,
      container: true,
      child: LiquidBox(
        style: _Chrome.modeTrack,
        // 40 tall including the rim, as the design's border-box track.
        height: 32,
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(ScanMode.receipt, tr.receipt),
            option(ScanMode.list, tr.writtenList),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.scanning,
    required this.onPhoto,
    required this.onShoot,
    required this.onType,
  });

  final bool scanning;
  final VoidCallback onPhoto;
  final VoidCallback onShoot;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LiquidPressable(
            onTap: scanning ? null : onPhoto,
            haptic: HapticKind.light,
            pressedScale: 0.92,
            borderRadius: 16,
            semanticLabel: tr.choosePhoto,
            child: const LiquidBox(
              style: _Chrome.sideButton,
              width: 50,
              height: 50,
              child: Center(
                child: LineIcon(
                  LineGlyph.photo,
                  size: 22,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          _Shutter(scanning: scanning, onTap: onShoot),
          LiquidPressable(
            onTap: scanning ? null : onType,
            haptic: HapticKind.light,
            pressedScale: 0.92,
            borderRadius: 16,
            semanticLabel: tr.typeInstead,
            child: const LiquidBox(
              style: _Chrome.sideButton,
              width: 52,
              height: 52,
              child: Center(
                child: LineIcon(
                  LineGlyph.pencil,
                  size: 20,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.scanning, required this.onTap});

  final bool scanning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: scanning ? null : onTap,
      haptic: HapticKind.medium,
      pressedScale: 0.92,
      semanticLabel: tr.scan,
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _Chrome.shutterRing, width: 4),
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 6),
              blurRadius: 20,
              color: Color.fromRGBO(0, 0, 0, 0.4),
            ),
          ],
        ),
        child: AnimatedScale(
          scale: scanning ? 0.82 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: scanning ? _Chrome.scanBlue : AppColors.white,
            ),
            duration: const Duration(milliseconds: 200),
            builder: (context, color, _) => LiquidBox(
              style: GlassStyle(
                radius: 32,
                color: color!,
                borderWidth: 0,
                shadows: const [
                  CssShadow.inset(
                    dy: -4,
                    blur: 8,
                    color: Color.fromRGBO(0, 0, 0, 0.08),
                  ),
                ],
              ),
              width: 64,
              height: 64,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Found n items": tick what to keep, fix prices, fill the bag.
class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.animation,
    required this.items,
    required this.source,
    required this.onChanged,
    required this.onRetake,
    required this.onFill,
  });

  final Animation<double> animation;
  final List<_ReviewItem> items;
  final String source;
  final VoidCallback onChanged;
  final VoidCallback onRetake;
  final VoidCallback onFill;

  /// The design's sheet: 484 tall, holding four lines.
  static const _restingHeight = 484.0;

  /// Sheet padding, grabber, header and buttons: everything but the list.
  static const _chrome = 8 + 5 + 14 + 40 + 14 + 58 + 22 + 2.0;
  static const _rowHeight = 50.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final bottom = keyboard > 0 ? keyboard + 8 : 8.0;
    final list = 10 + items.length * (_rowHeight + 1) - 1;
    final height = math
        .max(_restingHeight, _chrome + 16 + list)
        .clamp(0.0, mq.size.height - mq.padding.top - 17 - bottom);
    final on = items.where((i) => i.on);
    final sum = on.fold<double>(0, (s, i) => s + i.value);
    final palette = context.palette;

    return Positioned(
      left: 8,
      right: 8,
      bottom: bottom,
      height: height,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * (height + bottom + 40)),
          child: child,
        ),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: tr.foundItems(items.length),
          child: LiquidBox(
            style: palette.glass.scanSheet,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: 36,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.grabber,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReviewHeader(
                    title: tr.foundItems(items.length),
                    source: source,
                  ),
                  const SizedBox(height: 14),
                  // Takes what its lines need; scrolls once the sheet is full.
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: LiquidBox(
                        style: palette.glass.scanList,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _ReviewRow(
                            item: items[i],
                            divider: i > 0,
                            onChanged: onChanged,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 58,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RetakeButton(onTap: onRetake),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LiquidPressable(
                            onTap: onFill,
                            haptic: HapticKind.none,
                            pressedScale: 0.97,
                            borderRadius: 29,
                            child: LiquidBox(
                              style: _fillStyle,
                              child: Center(
                                child: Text(
                                  '${tr.fillTheBag} · ${formatMoney(sum)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.headline.copyWith(
                                    color: AppColors.white,
                                    fontFeatures: AppText.tabular,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _fillStyle = GlassStyle(
    radius: 28,
    color: AppColors.accent,
    borderColor: Color.fromRGBO(255, 255, 255, 0.4),
    shadows: [
      CssShadow.inset(dy: 1, color: Color.fromRGBO(255, 255, 255, 0.5)),
      CssShadow(dy: 12, blur: 28, color: Color.fromRGBO(10, 132, 255, 0.35)),
    ],
  );
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.title, required this.source});

  final String title;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                offset: Offset(0, 6),
                blurRadius: 14,
                color: Color.fromRGBO(52, 199, 89, 0.35),
              ),
            ],
          ),
          foregroundDecoration: const _RimDecoration(),
          child: const LineIcon(
            LineGlyph.tick,
            size: 20,
            strokeWidth: 3,
            color: AppColors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppText.title1.copyWith(
                    fontSize: 22,
                    height: 28 / 22,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote.copyWith(
                  color: context.palette.secondaryLabelStrong,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The green badge's `inset 0 1px 0 rgba(255,255,255,0.5)` top light.
class _RimDecoration extends Decoration {
  const _RimDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _RimPainter();
}

class _RimPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final circle = Path()..addOval(rect);
    canvas
      ..save()
      ..clipPath(circle)
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(rect)
          ..addOval(rect.shift(const Offset(0, 1))),
        Paint()..color = const Color.fromRGBO(255, 255, 255, 0.5),
      )
      ..restore();
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.item,
    required this.divider,
    required this.onChanged,
  });

  final _ReviewItem item;
  final bool divider;
  final VoidCallback onChanged;

  static final _priceFormat = [
    TextInputFormatter.withFunction(
      (_, value) => value.copyWith(text: asciiDigits(value.text)),
    ),
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final priceStyle = AppText.subheadBold.copyWith(
      color: palette.label,
      fontFeatures: AppText.tabular,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: palette.rowDivider))
            : null,
      ),
      child: Row(
        children: [
          LiquidPressable(
            onTap: () {
              item.on = !item.on;
              onChanged();
            },
            haptic: HapticKind.selection,
            pressedScale: 0.88,
            semanticLabel: item.on
                ? tr.leaveOut(item.name)
                : tr.include(item.name),
            selected: item.on,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.on ? AppColors.accent : const Color(0x000A84FF),
                    border: item.on
                        ? null
                        : Border.all(color: palette.offRing, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: item.on ? 1 : 0,
                    duration: Motion.snappy.duration,
                    curve: item.on ? Motion.bouncy : Curves.easeIn,
                    child: const LineIcon(
                      LineGlyph.tick,
                      size: 12,
                      strokeWidth: 3.4,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppText.base.copyWith(
                    fontSize: 16,
                    color: item.on ? palette.label : palette.offLabel,
                  ),
                  child: Text(
                    item.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.unsure) ...[
                  const SizedBox(height: 2),
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: palette.warnTint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LineIcon(
                          LineGlyph.alert,
                          size: 11,
                          strokeWidth: 2.6,
                          color: palette.warnLabel,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tr.checkPrice,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.warnLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 88,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: 1.5,
                color: item.unsure ? AppColors.orange : const Color(0x00FF9500),
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Text(
                    currencySymbol,
                    style: AppText.subhead.copyWith(
                      color: palette.secondaryLabelStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Semantics(
                    label: tr.priceFor(item.name),
                    child: CupertinoTextField.borderless(
                      controller: item.price,
                      placeholder: digits(0),
                      padding: EdgeInsets.zero,
                      textAlign: TextAlign.right,
                      style: priceStyle,
                      placeholderStyle: priceStyle.copyWith(
                        color: palette.placeholder,
                      ),
                      cursorColor: AppColors.accent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _priceFormat,
                      onChanged: (_) {
                        // A corrected price no longer needs checking.
                        item.unsure = false;
                        onChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RetakeButton extends StatelessWidget {
  const _RetakeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.light,
      pressedScale: 0.95,
      borderRadius: 28,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: palette.accentTint,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineIcon(
              LineGlyph.retake,
              size: 18,
              strokeWidth: 2.4,
              color: palette.accentText,
            ),
            const SizedBox(width: 6),
            Text(
              tr.retake,
              style: AppText.headline.copyWith(color: palette.accentText),
            ),
          ],
        ),
      ),
    );
  }
}
