class AppStrings {
  const AppStrings._(this._langCode);

  static AppStrings of(dynamic context) {
    return AppStrings._(_resolvedCode());
  }

  static String _resolvedCode() {
    try {
      return _LanguageServiceBridge.code;
    } catch (_) {
      return 'el';
    }
  }

  final String _langCode;
  bool get _isEl => _langCode == 'el';

  // ── Navigation ──────────────────────────────────────────────────────────
  String get home         => _isEl ? 'Αρχική'         : 'Home';
  String get bookings     => _isEl ? 'Κρατήσεις'      : 'Bookings';
  String get packages     => _isEl ? 'Πακέτα'         : 'Packages';
  String get profile      => _isEl ? 'Προφίλ'         : 'Profile';
  String get community    => _isEl ? 'Κοινότητα'      : 'Community';
  String get marketplace  => _isEl ? 'Κατάστημα'      : 'Shop';
  String get programs     => _isEl ? 'Προγράμματα'    : 'Programs';
  String get nutrition    => _isEl ? 'Διατροφή'       : 'Nutrition';
  String get workouts     => _isEl ? 'Προπονήσεις'    : 'Workouts';
  String get more         => _isEl ? 'Περισσότερα'    : 'More';

  // ── Greeting ─────────────────────────────────────────────────────────────
  String greeting(String name) => _isEl ? 'Γεια σου, $name!' : 'Hey, $name!';
  String get goodMorning   => _isEl ? 'Καλημέρα'     : 'Good morning';
  String get goodAfternoon => _isEl ? 'Καλησπέρα'    : 'Good afternoon';
  String get goodEvening   => _isEl ? 'Καλό βράδυ'   : 'Good evening';

  // ── QR ───────────────────────────────────────────────────────────────────
  String get qrTitle      => _isEl ? 'Check-in'       : 'Check-in';
  String get qrScanOption => _isEl ? 'Σκανάρισμα QR'  : 'Scan QR';
  String get qrShowOption => _isEl ? 'Το QR μου'      : 'My QR';
  String get qrScanDesc   => _isEl ? 'Σκανάρισε QR με την κάμερα σου' : 'Scan a QR code with your camera';
  String get qrShowDesc   => _isEl ? 'Δείξε τον κωδικό σου στο γυμναστήριο' : 'Show your code to the gym device';
  String get qrMemberId   => _isEl ? 'Κωδικός Μέλους' : 'Member ID';
  String get qrPresent    => _isEl ? 'Δείξε αυτόν τον κωδικό στη συσκευή του γυμναστηρίου'
                                   : 'Present this code to the gym scanner';

  // ── Language ─────────────────────────────────────────────────────────────
  String get languageLabel => _isEl ? 'Γλώσσα'        : 'Language';
  String get langGreek     => 'Ελληνικά';
  String get langEnglish   => 'English';

  // ── Orders ───────────────────────────────────────────────────────────────
  String get orders        => _isEl ? 'Παραγγελίες'   : 'Orders';
  String get noOrders      => _isEl ? 'Δεν υπάρχουν παραγγελίες' : 'No orders yet';

  // ── Common ───────────────────────────────────────────────────────────────
  String get cancel        => _isEl ? 'Άκυρο'         : 'Cancel';
  String get close         => _isEl ? 'Κλείσιμο'      : 'Close';
  String get loading       => _isEl ? 'Φόρτωση...'    : 'Loading...';
  String get retry         => _isEl ? 'Επανάληψη'     : 'Retry';
}

/// Thin bridge so AppStrings.of() doesn't need BuildContext.
class _LanguageServiceBridge {
  static String code = 'el';
}

void updateLanguageBridge(String code) {
  _LanguageServiceBridge.code = code;
}
