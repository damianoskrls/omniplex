import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'global_role_picker_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

class GlobalProfileDetailsScreen extends StatefulWidget {
  const GlobalProfileDetailsScreen({
    super.key,
    required this.globalAuth,
    required this.role,
    required this.onDone,
  });

  final GlobalAuthService globalAuth;
  final GlobalRole role;
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

  bool get _valid =>
      _nameCtrl.text.trim().length >= 2 &&
      _emailCtrl.text.trim().contains('@');

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
      await widget.globalAuth.updateProfile(
        fullName: _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
      );
      await widget.globalAuth.setPreferredRole(
        widget.role == GlobalRole.trainer ? 'staff' : 'member',
      );
      if (mounted) widget.onDone();
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrainer = widget.role == GlobalRole.trainer;

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

              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(height: 32),

              Text('Βήμα 2 από 2',
                style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kGray, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('Πές μας\nλίγα για σένα.',
                style: GoogleFonts.manrope(
                  fontSize: 30, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.75, height: 1.15)),
              const SizedBox(height: 8),
              Text(
                isTrainer
                  ? 'Συμπλήρωσε τα στοιχεία σου για να δημιουργήσουμε\nτο επαγγελματικό σου προφίλ.'
                  : 'Μόνο τα απαραίτητα — μπορείς να τα αλλάξεις\nαργότερα.',
                style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGray, height: 1.55)),

              const SizedBox(height: 36),

              // Full name
              _FieldLabel('Ονοματεπώνυμο'),
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

              // Email
              _FieldLabel('Email'),
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

              // Destination hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  Icon(
                    isTrainer ? Icons.sports_rounded : Icons.explore_outlined,
                    color: isTrainer ? const Color(0xFF3EE6FF) : _kLime,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTrainer
                        ? 'Θα μπορείς να αναζητήσεις το γυμναστήριό σου και να στείλεις αίτημα σύνδεσης.'
                        : 'Θα μπορείς να εξερευνήσεις γυμναστήρια και να αγοράσεις πακέτο.',
                      style: GoogleFonts.manrope(
                        fontSize: 12, color: _kGray, height: 1.45)),
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
                    border: Border.all(
                      color: _valid ? _kLime : _kBorder),
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
                    : Text(
                        isTrainer ? 'Ολοκλήρωση & Αναζήτηση Γυμναστηρίου'
                                  : 'Ολοκλήρωση & Εξερεύνηση',
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
        fontSize: 12, fontWeight: FontWeight.w600,
        color: _kGray, letterSpacing: 0.4));
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
