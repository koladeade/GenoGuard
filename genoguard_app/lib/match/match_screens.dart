import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../compat/compat_logic.dart';
import '../compat/compat_screens.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/nav_row.dart';
import 'match_api.dart';

/// Opens Match by QR from anywhere in the app.
void openMatchByQr(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MatchByQrScreen()));
}

MatchApi _api(BuildContext context) =>
    MatchApi(context.read<AuthState>().api.dio);

/// Both phones end here once the owner approved.
void _showResult(BuildContext context, ShareStatus s) {
  final you = s.you, partner = s.partner;
  if (you == null || partner == null) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => CompatibilityResultScreen(
        result: computeCompat(you, partner),
        note:
            'Based on the genotypes saved on your profile and ${s.otherName ?? 'their'} profile. '
            'These have not been independently verified.',
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Hub

class MatchByQrScreen extends StatelessWidget {
  const MatchByQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final genotype = context.watch<AuthState>().user?['genotype'] as String?;
    final ready = genotype != null;
    return AuthScaffold(
      title: 'Match by QR',
      subtitle:
          'Check compatibility with another GenoGuard user. Nothing is shared unless the code owner approves.',
      backTo: '/welcome',
      onBack: () => Navigator.of(context).pop(),
      children: [
        if (!ready) ...[
          AppCard(
            child: Text(
              'Add your genotype in Profile → Edit first. Both people need one to match.',
              style: AppText.body(16, FontWeight.w500, AppColors.gold),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Opacity(
          opacity: ready ? 1 : 0.45,
          child: NavRow(
            icon: Icons.qr_code_2,
            title: 'Show my code',
            subtitle: 'Let someone scan it. You approve each share.',
            onTap: () {
              if (ready)
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShowCodeScreen(),
                  ),
                );
            },
          ),
        ),
        Opacity(
          opacity: ready ? 1 : 0.45,
          child: NavRow(
            icon: Icons.qr_code_scanner,
            title: 'Scan a code',
            subtitle: 'Scan their QR, or type the code.',
            onTap: () {
              if (ready)
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScanCodeScreen(),
                  ),
                );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Person A: show my code, then approve or decline

enum _ShowPhase { creating, open, requested, ended }

class ShowCodeScreen extends StatefulWidget {
  const ShowCodeScreen({super.key});
  @override
  State<ShowCodeScreen> createState() => _ShowCodeScreenState();
}

class _ShowCodeScreenState extends State<ShowCodeScreen> {
  late final MatchApi _api0 = _api(context);
  _ShowPhase _phase = _ShowPhase.creating;
  CodeInfo? _info;
  DateTime? _deadline;
  int _left = 0;
  String? _requester;
  String? _msg;
  bool _busy = false;
  bool _polling = false;
  Timer? _poll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _poll?.cancel();
    _tick?.cancel();
  }

  Future<void> _create() async {
    _stopTimers();
    setState(() {
      _phase = _ShowPhase.creating;
      _msg = null;
      _requester = null;
    });
    try {
      final info = await _api0.createCode();
      if (!mounted) return;
      setState(() {
        _info = info;
        _deadline = DateTime.now().add(Duration(seconds: info.expiresIn));
        _left = info.expiresIn;
        _phase = _ShowPhase.open;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } catch (e) {
      if (mounted) _end(errMsg(e));
    }
  }

  void _end(String msg) {
    _stopTimers();
    setState(() {
      _phase = _ShowPhase.ended;
      _msg = msg;
    });
  }

  void _onTick() {
    if (!mounted || _deadline == null) return;
    final left = _deadline!.difference(DateTime.now()).inSeconds;
    if (left <= 0 &&
        (_phase == _ShowPhase.open || _phase == _ShowPhase.requested)) {
      _end('This code has expired. Make a new one to share again.');
      return;
    }
    setState(() => _left = left < 0 ? 0 : left);
  }

  Future<void> _check() async {
    if (_polling || _info == null || !mounted) return;
    if (_phase != _ShowPhase.open && _phase != _ShowPhase.requested) return;
    _polling = true;
    try {
      final s = await _api0.status(_info!.id);
      if (!mounted) return;
      switch (s.status) {
        case 'requested':
          if (_phase == _ShowPhase.open) {
            setState(() {
              _phase = _ShowPhase.requested;
              _requester = s.otherName;
            });
          }
        case 'approved':
          _stopTimers();
          _showResult(context, s);
        case 'declined':
          _end('Declined.');
        case 'expired':
          _end('This code has expired. Make a new one to share again.');
      }
    } catch (_) {
      // Network blip: the next poll will try again.
    } finally {
      _polling = false;
    }
  }

  Future<void> _decide(bool allow) async {
    setState(() => _busy = true);
    try {
      await _api0.decide(_info!.id, allow);
      if (!mounted) return;
      if (allow) {
        final s = await _api0.status(_info!.id);
        if (!mounted) return;
        _stopTimers();
        _showResult(context, s);
      } else {
        _end('You declined. Nothing was shared.');
      }
    } catch (e) {
      if (mounted) _end(errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _clock =>
      '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Your code',
    subtitle: 'Ask them to scan this, or type the code. It works once.',
    backTo: '/welcome',
    onBack: () => Navigator.of(context).pop(),
    children: switch (_phase) {
      _ShowPhase.creating => [
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ],
      _ShowPhase.open => [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: QrImageView(
              data: _info!.qrData,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            _info!.pretty,
            style: AppText.heading(34).copyWith(letterSpacing: 4),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Expires in $_clock',
            style: AppText.body(16, FontWeight.w600, AppColors.muted),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Only share this with the person you want to check with. You will be asked to approve before anything is shown.',
          textAlign: TextAlign.center,
          style: AppText.body(14, FontWeight.w500, AppColors.muted),
        ),
      ],
      _ShowPhase.requested => [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_requester ?? 'Someone'} wants to check compatibility with you',
                style: AppText.heading(24),
              ),
              const SizedBox(height: 8),
              Text(
                'If you allow, you will both see each other\'s genotype and the result. Expires in $_clock.',
                style: AppText.body(16, FontWeight.w500, AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton('Allow', busy: _busy, onPressed: () => _decide(true)),
        const SizedBox(height: 12),
        SecondaryButton(
          'Decline',
          onPressed: () => _busy ? null : _decide(false),
        ),
      ],
      _ShowPhase.ended => [
        AppCard(
          child: Text(
            _msg ?? 'This code has ended.',
            style: AppText.body(17, FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton('New code', onPressed: _create),
      ],
    },
  );
}

// ---------------------------------------------------------------------------
// Person B: scan or type a code, then wait for approval

enum _ScanPhase { scanning, claiming, waiting, ended }

class ScanCodeScreen extends StatefulWidget {
  const ScanCodeScreen({super.key});
  @override
  State<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends State<ScanCodeScreen> {
  late final MatchApi _api0 = _api(context);
  // The iOS simulator has no camera and the scanner can crash there, so the camera is opt-in
  // and not offered on simulators.
  late final bool _hasCamera =
      !(Platform.isIOS &&
          Platform.environment.containsKey('SIMULATOR_DEVICE_NAME'));
  MobileScannerController? _controller;
  bool _cameraOn = false;
  final _typed = TextEditingController();
  _ScanPhase _phase = _ScanPhase.scanning;
  String? _shareId;
  String? _ownerName;
  String? _err;
  bool _polling = false;
  Timer? _poll;
  String? _lastRaw;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _poll?.cancel();
    _typed.dispose();
    _controller?.dispose();
    super.dispose();
  }

  String _clean(String raw) => raw
      .toUpperCase()
      .replaceFirst('GENOGUARD:', '')
      .replaceAll(RegExp('[^A-Z0-9]'), '');

  Future<void> _claim(String raw) async {
    if (_phase != _ScanPhase.scanning) return;
    final code = _clean(raw);
    if (code.length != 8) {
      setState(() => _err = 'Enter the 8-character code');
      return;
    }
    setState(() {
      _closeCamera();
      _phase = _ScanPhase.claiming;
      _err = null;
    });
    try {
      final r = await _api0.claim(code);
      if (!mounted) return;
      _shareId = r.id;
      _ownerName = r.ownerName;
      setState(() => _phase = _ScanPhase.waiting);
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _ScanPhase.scanning;
          _err = errMsg(e);
        });
      }
    }
  }

  Future<void> _check() async {
    if (_polling || _shareId == null || !mounted) return;
    _polling = true;
    try {
      final s = await _api0.status(_shareId!);
      if (!mounted) return;
      switch (s.status) {
        case 'approved':
          _poll?.cancel();
          _showResult(context, s);
        case 'declined':
          _end('${_ownerName ?? 'They'} declined. Nothing was shared.');
        case 'expired':
          _end('The code expired before it was approved. Ask for a new one.');
      }
    } catch (_) {
      // Try again on the next poll.
    } finally {
      _polling = false;
    }
  }

  void _end(String msg) {
    _poll?.cancel();
    setState(() {
      _phase = _ScanPhase.ended;
      _err = msg;
    });
  }

  void _openCamera() => setState(() {
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
    _cameraOn = true;
  });

  void _closeCamera() {
    _controller?.dispose();
    _controller = null;
    _cameraOn = false;
  }

  void _again() => setState(() {
    _phase = _ScanPhase.scanning;
    _err = null;
    _typed.clear();
  });

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Scan a code',
    subtitle:
        'Point your camera at their QR. If they approve, you will both see each other\'s genotype and the result.',
    backTo: '/welcome',
    onBack: () => Navigator.of(context).pop(),
    children: switch (_phase) {
      _ScanPhase.scanning => [
        if (_cameraOn)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: MobileScanner(
                controller: _controller!,
                onDetect: (capture) {
                  final raw = capture.barcodes.isEmpty
                      ? null
                      : capture.barcodes.first.rawValue;
                  if (raw == null) return;
                  final now = DateTime.now();
                  if (raw == _lastRaw && now.difference(_lastAt).inSeconds < 5)
                    return;
                  _lastRaw = raw;
                  _lastAt = now;
                  _claim(raw);
                },
              ),
            ),
          )
        else if (_hasCamera)
          SecondaryButton('Open camera', onPressed: _openCamera)
        else
          AppCard(
            child: Text(
              'The simulator has no camera. Type the code below instead.',
              style: AppText.body(16, FontWeight.w500, AppColors.muted),
            ),
          ),
        if (_cameraOn)
          Center(
            child: TextButton(
              onPressed: () => setState(_closeCamera),
              child: Text(
                'Close camera',
                style: AppText.body(16, FontWeight.w700, AppColors.muted),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const FieldLabel('Type the code'),
        TextField(
          controller: _typed,
          textCapitalization: TextCapitalization.characters,
          style: AppText.body(20, FontWeight.w700).copyWith(letterSpacing: 3),
          decoration: const InputDecoration(hintText: 'K7M2 QX9P'),
        ),
        ErrorText(_err),
        const SizedBox(height: 16),
        PrimaryButton('Continue', onPressed: () => _claim(_typed.text)),
      ],
      _ScanPhase.claiming => [
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ],
      _ScanPhase.waiting => [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Waiting for ${_ownerName ?? 'them'} to approve',
                style: AppText.heading(24),
              ),
              const SizedBox(height: 8),
              Text(
                'They have been asked to confirm. Keep this screen open.',
                style: AppText.body(16, FontWeight.w500, AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton('Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
      _ScanPhase.ended => [
        AppCard(
          child: Text(
            _err ?? 'This share has ended.',
            style: AppText.body(17, FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton('Try again', onPressed: _again),
      ],
    },
  );
}
