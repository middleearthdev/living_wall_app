import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../application/providers/room_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../data/models/add_wall_context.dart';
import '../../../data/models/discovered_wall.dart';
import '../../../data/models/provision_payload.dart';
import '../../../data/services/qr_payload_parser.dart';
import '../../routing/routes.dart';
import '../../widgets/add_wall_chrome.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Reusable QR scan surface — used by:
/// - onboarding (between Discovery and Name & Place) for the first wall;
/// - add-wall flow for each subsequent wall;
/// - Wall Settings → "Konfigurasi ulang" to re-provision an existing wall.
///
/// Mandatory in primary onboarding/add-wall paths; manual entry is hidden
/// behind a small link as a fallback. For reconfigure, [discovered] and
/// [addContext] are both null — the route's [onScanned] callback knows
/// which existing wall to update.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({
    super.key,
    this.discovered,
    this.addContext,
    required this.onScanned,
  });

  /// The wall picked at Discovery — passed forward via the [onScanned]
  /// closure for onboarding/add-wall. Null for reconfigure (the route
  /// already knows which wall is being re-provisioned).
  final DiscoveredWall? discovered;

  /// Non-null when this screen is part of an add-wall flow (vs first-time
  /// onboarding). Drives the top bar and step pill. Null for reconfigure.
  final AddWallContext? addContext;

  /// Called with the validated payload after a successful scan or manual
  /// entry. Navigation + persistence is the caller's concern.
  final void Function(ProvisionPayload payload) onScanned;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  static const _parser = QrPayloadParser();

  late final MobileScannerController _controller;

  // Track the most recent invalid payload so we can show the reason
  // inline without spamming the user as the camera keeps re-detecting
  // the same code.
  String? _lastErrorMessage;
  String? _lastRejectedRaw;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_consumed) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _tryAccept(raw);
      if (_consumed) return;
    }
  }

  void _tryAccept(String raw) {
    try {
      final payload = _parser.parse(raw);
      _consumed = true;
      _controller.stop();
      widget.onScanned(payload);
    } on QrPayloadException catch (e) {
      if (_lastRejectedRaw == raw) return; // same code, already reported
      setState(() {
        _lastErrorMessage = e.message;
        _lastRejectedRaw = raw;
      });
    }
  }

  Future<void> _openManualEntry() async {
    final payload = await showModalBottomSheet<ProvisionPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).extension<LivingWallTheme>()!.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ManualEntrySheet(),
    );
    if (payload != null && mounted) {
      _consumed = true;
      _controller.stop();
      widget.onScanned(payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.addContext;
    final targetRoom = ctx == null
        ? null
        : ref.watch(roomByIdProvider(ctx.roomId));

    return OnboardingScaffold(
      stepLabel: ctx == null ? 'LANGKAH 3 / 4' : null,
      topBar: ctx == null
          ? null
          : AddWallTopBar(
              onConfirmedClose: () =>
                  context.go(Routes.dashboardRoom(ctx.roomId)),
            ),
      contextBanner: ctx == null
          ? null
          : AddWallContextBanner(roomName: targetRoom?.name ?? 'Ruangan'),
      title: 'Scan QR di label wall',
      subtitle:
          'Arahkan kamera ke kode QR yang ada di belakang panel. Ini memberi tahu app dimensi grid wall-mu.',
      body: _ScannerBody(
        controller: _controller,
        onDetect: _onDetect,
        errorMessage: _lastErrorMessage,
      ),
      secondaryAction: TextButton(
        onPressed: _openManualEntry,
        child: Text(
          'Tidak bisa scan? Input manual',
          style: TextStyle(
            color: Theme.of(context).extension<LivingWallTheme>()!.textDim,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ScannerBody extends StatelessWidget {
  const _ScannerBody({
    required this.controller,
    required this.onDetect,
    required this.errorMessage,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: controller, onDetect: onDetect),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ViewfinderPainter(strokeColor: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ext.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.surface3),
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(color: ext.textDim, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.strokeColor});

  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Centered square viewfinder, 70% of the shorter edge.
    final shortest = size.shortestSide;
    final box = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: shortest * 0.7,
      height: shortest * 0.7,
    );
    final corner = shortest * 0.08;

    void drawCorner(Offset start1, Offset end1, Offset start2, Offset end2) {
      canvas.drawLine(start1, end1, paint);
      canvas.drawLine(start2, end2, paint);
    }

    // Top-left
    drawCorner(
      box.topLeft,
      box.topLeft + Offset(corner, 0),
      box.topLeft,
      box.topLeft + Offset(0, corner),
    );
    // Top-right
    drawCorner(
      box.topRight,
      box.topRight - Offset(corner, 0),
      box.topRight,
      box.topRight + Offset(0, corner),
    );
    // Bottom-left
    drawCorner(
      box.bottomLeft,
      box.bottomLeft + Offset(corner, 0),
      box.bottomLeft,
      box.bottomLeft - Offset(0, corner),
    );
    // Bottom-right
    drawCorner(
      box.bottomRight,
      box.bottomRight - Offset(corner, 0),
      box.bottomRight,
      box.bottomRight - Offset(0, corner),
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}

/// Fallback for the rare case the QR is unreadable (damaged label, factory
/// bug). LED density is fixed at 60/m so the user only enters physical
/// dimensions + serial; grid LED counts are computed.
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  // Strip spec: WS2812B 60 LED/m → spacing 1.67cm along the strip length,
  // which becomes horizontal density when wired left-to-right.
  static const _ledsPerMeterHorizontal = 60;

  // Mounting spec: rows mounted in zig-zag at 5cm vertical pitch → 20 rows
  // per meter of wall height. Independent from strip density; this is an
  // industrial-design choice that affects total LED count + power but not
  // strip type.
  static const _ledsPerMeterVertical = 20;

  final _formKey = GlobalKey<FormState>();
  final _serialCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String? _topLevelError;

  @override
  void dispose() {
    _serialCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lengthMm = int.parse(_lengthCtrl.text.trim());
    final heightMm = int.parse(_heightCtrl.text.trim());
    final gridWidth = (lengthMm * _ledsPerMeterHorizontal / 1000).round();
    final gridHeight = (heightMm * _ledsPerMeterVertical / 1000).round();

    final payload = ProvisionPayload(
      version: 1,
      serialNumber: _serialCtrl.text.trim(),
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      lengthMm: lengthMm,
      heightMm: heightMm,
      wiringPattern: 'zigzag-bl-rm',
      tier: 'manual',
    );

    // Round-trip through the parser's validation rules so manual entry hits
    // the same envelope check as QR scan.
    try {
      const parser = QrPayloadParser();
      parser.parse(_buildUriFor(payload).toString());
    } on QrPayloadException catch (e) {
      setState(() => _topLevelError = e.message);
      return;
    }

    Navigator.of(context).pop(payload);
  }

  Uri _buildUriFor(ProvisionPayload p) => Uri(
    scheme: 'livingwall',
    host: 'provision',
    queryParameters: {
      'v': '${p.version}',
      'serial': p.serialNumber,
      'gw': '${p.gridWidth}',
      'gh': '${p.gridHeight}',
      'lw': '${p.lengthMm}',
      'lh': '${p.heightMm}',
      'wp': p.wiringPattern,
      if (p.tier != null) 'tier': p.tier!,
    },
  );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        // Sheet content + soft keyboard frequently exceeds the available
        // height on smaller phones; let it scroll instead of overflowing.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: ext.surface3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Input manual', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Fitur lanjutan. Pakai ini hanya kalau QR rusak — typo di dimensi bisa membuat scene rendering aneh tanpa error.',
                style: TextStyle(
                  color: ext.textDim,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _Field(
                controller: _serialCtrl,
                label: 'Serial number',
                hint: 'LW-2026-00342',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _lengthCtrl,
                label: 'Lebar (mm)',
                hint: '1200',
                keyboardType: TextInputType.number,
                validator: _validateMm,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _heightCtrl,
                label: 'Tinggi (mm)',
                hint: '800',
                keyboardType: TextInputType.number,
                validator: _validateMm,
              ),
              if (_topLevelError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _topLevelError!,
                  style: TextStyle(color: AppColors.high, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Simpan & lanjut', onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: TextStyle(color: ext.textDim, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateMm(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return 'Angka tidak valid';
    return null;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<LivingWallTheme>()!;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: ext.textDim, fontSize: 13),
        hintStyle: TextStyle(color: ext.textFaint),
        filled: true,
        fillColor: ext.surface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}
