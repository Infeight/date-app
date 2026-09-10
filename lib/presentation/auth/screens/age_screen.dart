import 'package:dating_app/core/extensions/unfocus_on_tap_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/step_header.dart';
import 'basics_screen1.dart';

class AgeScreen extends ConsumerStatefulWidget {
  const AgeScreen({super.key});

  @override
  ConsumerState<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends ConsumerState<AgeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
    DateTime? _selectedDate;
  bool _isAdult = false;
  bool _isLoading = false;

Future<void> _onContinue() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter your display name');
      return;
    }
    if (_selectedDate == null) {
      _showSnack('Please select your birth date');
      return;
    }
    if (!_isAdult) {
      _showSnack('You must be 18 or older to continue');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dob = _selectedDate!.toIso8601String().split('T').first;
      final me = await ref.read(onboardingRepositoryProvider).updateAge(dob);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BasicsScreen(displayName: _nameController.text.trim()),
          ),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 1, now.month, now.day); // allow selection, we check after
    final minDate = DateTime(now.year - 80);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: minDate,
      lastDate: maxDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onAccent,
              surface: AppColors.card,
              onSurface: AppColors.textDark,
            ),
            dialogBackgroundColor: AppColors.card,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = DateTime.now().difference(picked).inDays ~/ 365;
      final isEighteenPlus = age >= 18;

      setState(() {
        _selectedDate = picked;
        _dayController.text = picked.day.toString().padLeft(2, '0');
        _monthController.text = picked.month.toString().padLeft(2, '0');
        _yearController.text = picked.year.toString();
        _isAdult = isEighteenPlus; // auto check if 18+, auto uncheck if not
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wordmark(),
                  Icon(Icons.tune, color: AppColors.textDark),
                ],
              ),

              const SizedBox(height: 40),

              // Heading
              Text(
                'How old are you?',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: 8),
              Text(
                'Cozune is for adults only. Please share your birth date.',
                style: TextStyle(fontSize: 14, color: AppColors.textGrey),
              ),

              const SizedBox(height: 32),

              // Display name label
              Text(
                'DISPLAY NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 15, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'How should we call you?',
                  hintStyle: TextStyle(color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),

             
             // DOB row
              Row(
                children: [
                  _dobField('DAY', 'DD', _dayController, 2),
                  const SizedBox(width: 12),
                  _dobField('MONTH', 'MM', _monthController, 2),
                  const SizedBox(width: 12),
                  _dobField('YEAR', 'YYYY', _yearController, 4),
                ],
              ),
              const SizedBox(height: 28),

              // 18+ checkbox
              GestureDetector(
                onTap: _selectedDate == null
                    ? () => _showSnack('Please select your birth date first')
                    : null, // locked — controlled by calendar result only
               child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isAdult
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : (_selectedDate != null
                            ? AppColors.danger.withValues(alpha: 0.08) // tint if picked but underage
                            : AppColors.card),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAdult
                          ? AppColors.primary
                          : (_selectedDate != null
                              ? Colors.red.shade200
                              : AppColors.inputBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isAdult
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          border: Border.all(
                            color: _isAdult
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: _isAdult
                            ? Icon(Icons.check,
                                size: 14, color: AppColors.onAccent)
                            : (_selectedDate != null
                                ? const Icon(Icons.close,
                                    size: 14, color: Colors.red)
                                : null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isAdult
                              ? "I confirm I'm 18 or older"
                              : (_selectedDate != null
                                  ? "You must be 18 or older to use cozune"
                                  : "I confirm I'm 18 or older"),
                          style: TextStyle(
                            fontSize: 14,
                            color: _isAdult
                                ? AppColors.textDark
                                : (_selectedDate != null
                                    ? Colors.red.shade400
                                    : AppColors.textGrey),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_selectedDate != null && !_isAdult)
                        const Icon(Icons.lock_outline,
                            size: 16, color: Colors.red),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Info notes.
              //
              // This one used to advertise "the adult layer", which told anyone
              // reading the screen — a store reviewer included — that the app
              // has one. It now says what the date of birth is actually for.
              _infoNote(
                Icons.info_outline,
                "We use your date of birth to confirm you're 18+. It stays "
                'private — only your age is shown.',
              ),
              const SizedBox(height: 12),
              _infoNote(
                Icons.chat_bubble_outline,
                'A verification code (OTP) may be sent to confirm your birth date if required.',
              ),

              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.onAccent)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onAccent,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: AppColors.onAccent, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ).unfocusOnTap(),
    );
  }

  Widget _dobField(String label, String hint,
      TextEditingController controller, int maxLen) {
    final isFilled = controller.text.isNotEmpty;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                readOnly: true,
                style: TextStyle(
                  fontSize: 15,
                  color: isFilled ? AppColors.textDark : AppColors.textGrey,
                  fontWeight: isFilled ? FontWeight.w600 : FontWeight.normal,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: hint,
                  hintStyle: TextStyle(color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isFilled ? AppColors.primary : AppColors.inputBorder,
                      width: isFilled ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isFilled ? AppColors.primary : AppColors.inputBorder,
                      width: isFilled ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoNote(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ),
      ],
    );
  }
}