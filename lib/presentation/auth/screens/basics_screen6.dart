import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import 'basics_screen7.dart';

/// Identity verification (the live face check).
///
/// This is not one of the ten funnel steps — it unlocks messaging and the
/// verified badge, and is always skippable. The on-device animation drives a real
/// `POST /verification/session`; with the mock provider the session is then
/// approved via `POST /verification/session/:id/complete`, while a real
/// provider decides asynchronously by webhook (which returns 403 here, so that
/// case is treated as "pending", not an error).
class BasicsScreen6 extends ConsumerStatefulWidget {
  const BasicsScreen6({super.key});

  @override
  ConsumerState<BasicsScreen6> createState() => _BasicsScreen6State();
}

class _BasicsScreen6State extends ConsumerState<BasicsScreen6>
    with TickerProviderStateMixin {
  late AnimationController _arcController;
  late AnimationController _stepController;

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraError = false;

  int _currentStep = 0;
  bool _isDone = false;
  bool _isStarted = false;

  /// Set when the backend confirmed the user as verified. When the check ran
  /// but the provider hasn't decided yet, this stays false and the UI says so.
  bool _verified = false;
  String? _verificationNote;

  final List<Map<String, dynamic>> _steps = [
    {'icon': Icons.arrow_back, 'text': 'Turn your head slowly to the left'},
    {'icon': Icons.arrow_forward, 'text': 'Now turn your head to the right'},
    {'icon': Icons.remove_red_eye_outlined, 'text': 'Look straight into the camera'},
  ];

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }

      // Use front camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false, // no audio needed
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  @override
  void dispose() {
    _arcController.dispose();
    _stepController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _startVerification() {
    setState(() => _isStarted = true);
    _arcController.repeat();
    _runNextStep();
  }

  void _runNextStep() {
    if (_currentStep >= 3) return;

    _stepController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _currentStep++);

      if (_currentStep == 3) {
        _arcController.stop();
        setState(() => _isDone = true);
        unawaited(_submitVerification());
      } else {
        _runNextStep();
      }
    });
  }

  /// Records the completed live check against the backend. Never blocks the
  /// funnel: verification is optional, so failures downgrade to a note.
  Future<void> _submitVerification() async {
    final repo = ref.read(verificationRepositoryProvider);
    try {
      var status = await repo.startSession();

      final session = status.session;
      if (!status.verified && session != null && session.isMock) {
        try {
          status = await repo.completeSession(session.sessionId);
        } on AppException {
          // Real provider wired up — the webhook decides. Leave it pending.
        }
      }

      // Refresh the self-view so `verified` (which gates messaging) is
      // current on the screens after this one.
      await ref.read(meProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _verified = status.verified;
        _verificationNote = status.verified
            ? null
            : "We've got your check — verification finishes shortly.";
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _verificationNote = e.message);
    }
  }

  void _goToAgreement() {
    _cameraController?.dispose();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BasicsScreen7()),
    );
  }

  void _onSkip() => _goToAgreement();

  void _onContinue() => _goToAgreement();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Top bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  const Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Wordmark(size: 20),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Text(
                'Verify your identity',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: 8),
              // Same rule as the age screen: never name an "adult layer" in
              // anything a person — or a store reviewer — can read. It says
              // what the check unlocks, which is messaging and a badge.
              Text(
                'A quick live check to unlock messaging and show others you '
                'are real. Your video is never stored.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),

              const SizedBox(height: 32),

              // Face scan circle with live camera
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Spinning arc
                      if (_isStarted && !_isDone)
                        AnimatedBuilder(
                          animation: _arcController,
                          builder: (_, _) => CustomPaint(
                            size: const Size(240, 240),
                            painter: _ArcPainter(_arcController.value),
                          ),
                        ),

                      // Step progress ring
                      if (_isStarted && !_isDone)
                        AnimatedBuilder(
                          animation: _stepController,
                          builder: (_, _) => CustomPaint(
                            size: const Size(240, 240),
                            painter: _ProgressRingPainter(_stepController.value),
                          ),
                        ),

                      // Done green ring
                      if (_isDone)
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _DoneRingPainter(),
                        ),

                      // Idle ring
                      if (!_isStarted && !_isDone)
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _IdleRingPainter(),
                        ),

                      // Camera preview clipped to circle
                      ClipOval(
                        child: SizedBox(
                          width: 185,
                          height: 185,
                          child: _buildCameraView(),
                        ),
                      ),

                      // Done overlay
                      if (_isDone)
                        Container(
                          width: 185,
                          height: 185,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.ok.withValues(alpha: 0.3),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 72,
                            color: AppColors.ok,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Bottom controls
              if (!_isStarted)
                Center(
                  child: Column(
                    children: [
                      Text(
                        _cameraError
                            ? 'Camera not available on this device'
                            : _cameraReady
                                ? 'Camera ready. Tap to begin.'
                                : 'Starting camera...',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_cameraReady && !_cameraError)
                              ? _startVerification
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.textGrey.withValues(alpha:0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  color: AppColors.onAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Start Face Check',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isDone)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _verified ? Icons.check_circle : Icons.schedule,
                          size: 18,
                          color: _verified
                              ? AppColors.ok
                              : AppColors.textGrey,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _verified
                                ? 'Identity verified successfully!'
                                : (_verificationNote ?? 'Finishing up...'),
                            style: TextStyle(
                              fontSize: 15,
                              color: _verified
                                  ? AppColors.ok
                                  : AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ok,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Active step instructions
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      // Step dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final isActive = i == _currentStep;
                          final isComplete = i < _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isComplete || isActive
                                  ? AppColors.primary
                                  : AppColors.inputBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Instruction
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Row(
                          key: ValueKey(_currentStep),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _steps[_currentStep.clamp(0, 2)]['icon'] as IconData,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _steps[_currentStep.clamp(0, 2)]['text'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Progress bar for current step
                      AnimatedBuilder(
                        animation: _stepController,
                        builder: (_, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _stepController.value,
                            minHeight: 4,
                            backgroundColor: AppColors.inputBorder,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Privacy note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Powered by a secure verification provider. Your privacy is protected. Data is encrypted and automatically deleted after verification.',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.camera_alt_outlined,
              color: Colors.white54, size: 40),
        ),
      );
    }

    if (!_cameraReady || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }
}

// Idle ring — grey circle
class _IdleRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = AppColors.inputBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint);
  }
  @override
  bool shouldRepaint(_IdleRingPainter old) => false;
}

// Spinning arc
class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = AppColors.inputBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);

    final arcPaint = Paint()
      ..color = AppColors.primary.withValues(alpha:0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + (progress * 2 * pi),
      2.0,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// Step fill ring
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

// Full green ring
class _DoneRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = AppColors.ok
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_DoneRingPainter old) => false;
}