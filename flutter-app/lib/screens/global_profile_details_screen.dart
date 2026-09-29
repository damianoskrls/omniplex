import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'global_role_picker_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

/// Shown to new users after OTP verification.
/// Collects name (required) + email (optional), then shows optional role picker.
class GlobalProfileDetailsScreen extends StatefulWidget {
  const GlobalProfileDetailsScreen({
    super.key,
    required this.globalAuth,
    required this.onDone,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onDone;

  @override
  State<GlobalProfileDetailsScreen> createState() =>
      _GlobalProfileDetailsScreenState();
}

class _GlobalProfileDetailsScreenState
    extends State<GlobalProfileDetailsScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _valid => _nameCtrl.text.trim().length >= 2;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() { _saving = true; _error = null; });
    try {
      final email = _emailCtrl.text.trim();
      await widget.globalAuth.updateProfile(
        fullName: _nameCtrl.text.trim(),
        email: email.isNotEmpty ? email : null,
      );
      if (!mounted) return;
      // Proceed to optional role picker
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => GlobalRolePickerScreen(
          globalAuth: widget.globalAuth,
          isOptional: true,
          onDone: (_) => widget.onDone(),
        ),
      ));
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Back — log out so the new user doesn't remain with an empty/default name
              GestureDetector(
                onTap: () async {
                  await widget.globalAuth.clear();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(height: 32),

              Text('Βήμα 1 από 2',
                style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kGray, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('Πές μας\nλίγα για σένα.',
                style: GoogleFonts.manrope(
                  fontSize: 30, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.75, height: 1.15)),
              const SizedBox(height: 8),
              Text('Μόνο τα απαραίτητα — μπορείς να τα αλλάξεις αργότερα.',
                style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.55)),

              const SizedBox(height: 36),

              // Full name (required)
              _FieldLabel('Ονοματεπώνυμο *'),
              const SizedBox(height: 8),
              _InputField(
                controller: _nameCtrl,
                hint: 'π.χ. Γιάννης Παπαδόπουλος',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                autofocus: true,
              ),

              const SizedBox(height: 20),

              // Email (optional)
              _FieldLabel('Email (προαιρετικά)'),
              const SizedBox(height: 8),
              _InputField(
                controller: _emailCtrl,
                hint: 'user@email.com',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1414),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF5C1E1E)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFF87171), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5, color: const Color(0xFFF87171))),
                    ),
                  ]),
                ),
              ],

              const Spacer(),

              // Info hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _kLime, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Στο επόμενο βήμα θα επιλέξεις ρόλο — μπορείς να το παραλείψεις.',
                      style: GoogleFonts.manrope(fontSize: 12, color: _kGray, height: 1.45)),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Save button
              GestureDetector(
                onTap: (_valid && !_saving) ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _valid ? _kLime : _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _valid ? _kLime : _kBorder),
                    boxShadow: _valid ? [
                      BoxShadow(
                        color: _kLime.withValues(alpha: 0.28),
                        blurRadius: 16, offset: const Offset(0, 6)),
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Color(0xFF0A0A0A), strokeWidth: 2.5))
                    : Text('Συνέχεια',
                        style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _valid ? _kBg : _kGray)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w600, color: _kGray, letterSpacing: 0.4));
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        cursorColor: _kLime,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(color: _kGray, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
