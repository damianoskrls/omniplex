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
  String get myQrTitle    => _isEl ? 'Το QR μου'      : 'My QR';
  String get qrUnlimited  => _isEl ? 'Απεριόριστες συνεδρίες' : 'Unlimited sessions';
  String qrRemaining(int n) => _isEl ? 'Απομένουν $n συνεδρίες' : '$n sessions remaining';
  String get qrCheckinWithQr => _isEl ? 'Check-in με QR' : 'Check-in with QR';
  String get qrScanGym    => _isEl ? 'Σκανάρετε το QR του γυμναστηρίου.\nΘα επιλέξετε για ποια κράτηση κάνετε check-in.' : 'Scan the gym QR code.\nYou will choose which booking to check in for.';
  String get qrCameraUnavailable => _isEl ? 'Κάμερα μη διαθέσιμη σε αυτή τη συσκευή' : 'Camera unavailable on this device';
  String get qrCheckinDone => _isEl ? 'Check-in ολοκληρώθηκε' : 'Check-in complete';
  String qrWelcome(String name) => _isEl ? 'Καλώς ήρθες, $name!' : 'Welcome, $name!';
  String get qrUnlimitedSub => _isEl ? 'Απεριόριστη συνδρομή' : 'Unlimited subscription';
  String get qrSelectBooking => _isEl ? 'Επέλεξε κράτηση' : 'Select booking';
  String get qrMultipleAvail => _isEl ? 'Έχεις περισσότερα από ένα μάθημα διαθέσιμο για check-in τώρα.' : 'You have more than one class available for check-in right now.';
  String get qrConfirmCheckin => _isEl ? 'Επιβεβαίωση check-in' : 'Confirm check-in';
  String get qrManualConfirm  => _isEl ? 'Επιβεβαίωση χειροκίνητα' : 'Manual confirmation';
  String get qrRetry          => _isEl ? 'Δοκίμασε ξανά' : 'Try again';
  String get qrError          => _isEl ? 'Σφάλμα. Προσπάθησε ξανά.' : 'Error. Please try again.';
  String get qrCheckinInProgress => _isEl ? 'Γίνεται check-in...' : 'Checking in...';

  // ── Language ─────────────────────────────────────────────────────────────
  String get languageLabel => _isEl ? 'Γλώσσα'        : 'Language';
  String get langGreek     => 'Ελληνικά';
  String get langEnglish   => 'English';

  // ── Orders ───────────────────────────────────────────────────────────────
  String get orders        => _isEl ? 'Παραγγελίες'   : 'Orders';
  String get noOrders      => _isEl ? 'Δεν υπάρχουν παραγγελίες' : 'No orders yet';
  String get myOrders      => _isEl ? 'Οι Παραγγελίες μου' : 'My Orders';
  String get ordersEmptySubtitle => _isEl ? 'Οι παραγγελίες σου θα εμφανίζονται εδώ' : 'Your orders will appear here';
  String get orderTotal    => _isEl ? 'Σύνολο'        : 'Total';
  String get orderProducts => _isEl ? 'Προϊόντα'      : 'Products';
  String get orderProgress => _isEl ? 'Πορεία'        : 'Progress';
  String get orderStatusPending   => _isEl ? 'Εκκρεμεί'       : 'Pending';
  String get orderStatusPaid      => _isEl ? 'Πληρώθηκε'      : 'Paid';
  String get orderStatusProcessing => _isEl ? 'Σε επεξεργασία' : 'Processing';
  String get orderStatusReady     => _isEl ? 'Έτοιμη'         : 'Ready';
  String get orderStatusCancelled => _isEl ? 'Ακυρώθηκε'      : 'Cancelled';
  String get orderStatusRefunded  => _isEl ? 'Επιστροφή'      : 'Refunded';
  String get orderStatusPending2  => _isEl ? 'Εκκρεμεί'       : 'Pending';
  String get orderStatusPaid2     => _isEl ? 'Πληρώθηκε'      : 'Paid';
  String get orderStatusProcessing2 => _isEl ? 'Επεξ.'        : 'Proc.';
  String get orderStatusReady2    => _isEl ? 'Έτοιμη'         : 'Ready';

  // ── Common ───────────────────────────────────────────────────────────────
  String get cancel        => _isEl ? 'Άκυρο'         : 'Cancel';
  String get close         => _isEl ? 'Κλείσιμο'      : 'Close';
  String get loading       => _isEl ? 'Φόρτωση...'    : 'Loading...';
  String get retry         => _isEl ? 'Επανάληψη'     : 'Retry';
  String get retryBtn      => _isEl ? 'Δοκίμασε ξανά' : 'Try again';
  String get save          => _isEl ? 'Αποθήκευση'    : 'Save';
  String get saving        => _isEl ? 'Αποθήκευση...' : 'Saving...';
  String get submit        => _isEl ? 'Υποβολή'       : 'Submit';
  String get confirm       => _isEl ? 'Επιβεβαίωση'   : 'Confirm';
  String get yes           => _isEl ? 'Ναι'           : 'Yes';
  String get no            => _isEl ? 'Όχι'           : 'No';
  String get ok            => _isEl ? 'Εντάξει'       : 'OK';
  String get delete        => _isEl ? 'Διαγραφή'      : 'Delete';
  String get error         => _isEl ? 'Σφάλμα'        : 'Error';
  String get required      => _isEl ? 'Απαιτείται'    : 'Required';
  String get optional      => _isEl ? 'προαιρετικό'   : 'optional';
  String get today         => _isEl ? 'Σήμερα'        : 'Today';
  String get yesterday     => _isEl ? 'Χθες'          : 'Yesterday';
  String get justNow       => _isEl ? 'Μόλις τώρα'    : 'Just now';
  String get now           => _isEl ? 'Τώρα'          : 'Now';
  String get notes         => _isEl ? 'Σημειώσεις'    : 'Notes';
  String get phone         => _isEl ? 'Τηλέφωνο'      : 'Phone';
  String get email         => _isEl ? 'Email'          : 'Email';
  String get address       => _isEl ? 'Διεύθυνση'     : 'Address';
  String get next          => _isEl ? 'Επόμενο'       : 'Next';
  String get skip          => _isEl ? 'Παράλειψη'     : 'Skip';
  String get start         => _isEl ? 'Ξεκινάμε!'     : 'Let\'s go!';
  String get weight        => _isEl ? 'Βάρος'         : 'Weight';
  String get height        => _isEl ? 'Ύψος'          : 'Height';
  String get goal          => _isEl ? 'Στόχος'        : 'Goal';
  String get goals         => _isEl ? 'Στόχοι'        : 'Goals';
  String get copy          => _isEl ? 'Αντιγραφή'     : 'Copy';
  String minutesAgo(int m) => _isEl ? 'Πριν $m λεπτά' : '$m min ago';
  String hoursAgo(int h)   => _isEl ? 'Πριν $h ώρες'  : '$h hr ago';
  String daysAgo(int d)    => _isEl ? 'Πριν $d μέρες' : '$d days ago';
  String get logout        => _isEl ? 'Αποσύνδεση'    : 'Logout';
  String get activeMember  => _isEl ? 'Ενεργό μέλος'  : 'Active member';
  String get unexpectedError => _isEl ? 'Απροσδόκητο σφάλμα. Δοκίμασε ξανά.' : 'Unexpected error. Please try again.';

  // ── Login ────────────────────────────────────────────────────────────────
  String get loginTitle     => _isEl ? 'Σύνδεση'          : 'Login';
  String get loginMobile    => _isEl ? 'Κινητό τηλέφωνο'  : 'Mobile phone';
  String get loginPin       => _isEl ? 'Κωδικός PIN'       : 'PIN code';
  String get loginEnterMobile => _isEl ? 'Εισάγετε τον αριθμό κινητού σας' : 'Enter your mobile number';
  String get loginEnterPin  => _isEl ? 'Εισάγετε 4ψήφιο PIN' : 'Enter 4-digit PIN';
  String get loginOrWith    => _isEl ? 'ή συνδέσου με κινητό & PIN' : 'or sign in with mobile & PIN';
  String get loginWithBiometric => _isEl ? 'Είσοδος με' : 'Sign in with';
  String get loginForgotPin => _isEl ? 'Ξέχασες τον κωδικό;' : 'Forgot your code?';
  String get loginForgotPinTitle => _isEl ? 'Ξέχασες τον κωδικό;' : 'Forgot your code?';
  String get loginForgotPinBody  => _isEl ? 'Επικοινώνησε με το γυμναστήριο για επαναφορά του κωδικού σου.' : 'Contact the gym to reset your code.';
  String get loginNoAccount => _isEl ? 'Δεν έχεις λογαριασμό; Εγγραφή' : 'No account? Register';
  String get loginAsStaff   => _isEl ? 'Είσοδος ως Προσωπικό' : 'Sign in as Staff';
  String get loginStaffTitle => _isEl ? 'Είσοδος προσωπικού' : 'Staff login';
  String get loginPassword  => _isEl ? 'Κωδικός'            : 'Password';
  String get loginEnterEmail => _isEl ? 'Εισάγετε το email σας' : 'Enter your email';
  String get loginEnterPassword => _isEl ? 'Εισάγετε τον κωδικό σας' : 'Enter your password';
  String get loginBiometricFailed => _isEl ? 'Η βιομετρική είσοδος απέτυχε.' : 'Biometric sign-in failed.';
  String get loginAfterFirst => _isEl ? 'Μετά την πρώτη σύνδεση μπορείς να ενεργοποιήσεις βιομετρική είσοδο.' : 'After first sign-in you can enable biometric login.';
  String get loginSwitchGym => _isEl ? 'Αλλαγή γυμναστηρίου' : 'Switch gym';
  String loginEnableBiometricTitle(String label) => _isEl ? 'Είσοδος με $label;' : 'Sign in with $label?';
  String loginEnableBiometricBody(String label) => _isEl ? 'Θέλεις να χρησιμοποιείς $label την επόμενη φορά;' : 'Do you want to use $label next time?';
  String get loginEnableBiometricEnable => _isEl ? 'Ενεργοποίηση' : 'Enable';
  String get loginNotNow    => _isEl ? 'Όχι τώρα'            : 'Not now';
  String get loginBookEasy  => _isEl ? 'Κράτησε εύκολα το επόμενο ραντεβού σου.' : 'Book your next appointment easily.';

  // ── Register ─────────────────────────────────────────────────────────────
  String get registerTitle     => _isEl ? 'Αίτηση εγγραφής'   : 'Registration Request';
  String get registerMembership => _isEl ? 'Εγγραφή μέλους'   : 'Member Registration';
  String get registerCreateAccount => _isEl ? 'Δημιουργία λογαριασμού' : 'Create account';
  String get registerSubtitle  => _isEl ? 'Συμπλήρωσε τα στοιχεία σου. Ο διαχειριστής θα εγκρίνει την αίτησή σου και θα σου στείλει SMS.' : 'Fill in your details. The admin will approve your request and send you an SMS.';
  String get registerFullName  => _isEl ? 'Ονοματεπώνυμο *'   : 'Full name *';
  String get registerMobile    => _isEl ? 'Κινητό τηλέφωνο *' : 'Mobile phone *';
  String get registerEmail     => _isEl ? 'Email (προαιρετικό)' : 'Email (optional)';
  String get registerBranch    => _isEl ? 'Κατάστημα *'        : 'Branch *';
  String get registerChoosePin => _isEl ? 'Επίλεξε κωδικό (4 ψηφία)' : 'Choose a PIN (4 digits)';
  String get registerPinHint   => _isEl ? 'Με αυτόν θα συνδέεσαι στην εφαρμογή' : 'You will use this to sign in to the app';
  String get registerSubmit    => _isEl ? 'Υποβολή αίτησης'   : 'Submit request';
  String get registerSentTitle => _isEl ? 'Αίτηση στάλθηκε!'  : 'Request sent!';
  String get registerSentBody  => _isEl ? 'Η αίτησή σου καταχωρήθηκε. Θα λάβεις SMS μόλις το γυμναστήριο εγκρίνει τον λογαριασμό σου.' : 'Your request has been submitted. You will receive an SMS when the gym approves your account.';
  String get registerBackToLogin => _isEl ? 'Επιστροφή στη σύνδεση' : 'Back to login';
  String get registerSelectBranch => _isEl ? 'Επίλεξε κατάστημα' : 'Select branch';
  String get registerEnterPin => _isEl ? 'Εισάγετε 4ψήφιο κωδικό' : 'Enter 4-digit code';
  String get registerNameRequired => _isEl ? 'Απαιτείται όνομα' : 'Name is required';
  String get registerMobileRequired => _isEl ? 'Απαιτείται κινητό' : 'Mobile is required';
  String get registerInvalidMobile => _isEl ? 'Μη έγκυρος αριθμός' : 'Invalid number';
  String get registerInvalidEmail => _isEl ? 'Μη έγκυρο email' : 'Invalid email';
  String get registerBranchRequired => _isEl ? 'Επίλεξε κατάστημα' : 'Select a branch';

  // ── Bookings ─────────────────────────────────────────────────────────────
  String get myBookingsTitle   => _isEl ? 'Κρατήσεις'         : 'Bookings';
  String get noBookings        => _isEl ? 'Δεν έχεις κρατήσεις ακόμα' : 'No bookings yet';
  String get noBookingsSubtitle => _isEl ? 'Κλείσε το πρώτο σου ραντεβού από την καρτέλα Κράτηση.' : 'Book your first appointment from the Booking tab.';
  String get noActiveAppointments => _isEl ? 'Δεν έχεις ενεργά ραντεβού' : 'No active appointments';
  String get noActiveAppointmentsSubtitle => _isEl ? 'Τα ολοκληρωμένα βρίσκονται παραπάνω.' : 'Completed ones are above.';
  String get cancelBookingTitle => _isEl ? 'Ακύρωση κράτησης' : 'Cancel booking';
  String cancelBookingContent(String name) => _isEl ? 'Να ακυρωθεί η κράτηση για $name;' : 'Cancel the booking for $name?';
  String get bookingCancelled  => _isEl ? 'Η κράτηση ακυρώθηκε' : 'Booking cancelled';
  String get cancelWaitlistTitle => _isEl ? 'Αποχώρηση από αναμονή' : 'Leave waitlist';
  String cancelWaitlistContent(String name) => _isEl ? 'Να αφαιρεθείς από την αναμονή για $name;' : 'Remove yourself from the waitlist for $name?';
  String get waitlistLeft      => _isEl ? 'Αφαιρέθηκες από τη λίστα αναμονής' : 'Removed from waitlist';
  String waitlistPosition(int pos) => _isEl ? 'Θέση #$pos στη λίστα αναμονής' : 'Position #$pos on waitlist';
  String get waitlistOpened    => _isEl ? 'Άνοιξε θέση — θα ενημερωθείς μόλις επιβεβαιωθεί η κράτηση.' : 'A spot opened — you will be notified when the booking is confirmed.';
  String get leaveWaitlist     => _isEl ? 'Αποχώρηση από αναμονή' : 'Leave waitlist';
  String get bookingStatusConfirmed   => _isEl ? 'Επιβεβαιωμένη'         : 'Confirmed';
  String get bookingStatusPending     => _isEl ? 'Αναμονή επιβεβαίωσης'  : 'Awaiting confirmation';
  String get bookingStatusCancelled   => _isEl ? 'Ακυρωμένη'             : 'Cancelled';
  String get bookingStatusCompleted   => _isEl ? 'Ολοκληρωμένη'          : 'Completed';
  String get bookingStatusNoShow      => _isEl ? 'Απόντας'               : 'No show';
  String get bookingStatusNoCheckin   => _isEl ? 'Χωρίς check-in'        : 'No check-in';
  String get bookingPendingConfirm    => _isEl ? 'Αναμονή επιβεβαίωσης'  : 'Awaiting confirmation';
  String get waitlistSection           => _isEl ? 'Λίστα αναμονής'        : 'Waitlist';
  String get pendingAttendanceSection  => _isEl ? 'Εκκρεμεί επιβεβαίωση' : 'Pending attendance';
  String noCheckinCount(int n) => _isEl ? '$n προπόνηση${n == 1 ? '' : 'εις'} χωρίς check-in' : '$n workout${n == 1 ? '' : 's'} without check-in';
  String get completedSection  => _isEl ? 'Ολοκληρωμένα'     : 'Completed';
  String get completedSubtitle => _isEl ? 'προπονήσεις · στόχοι & KPIs' : 'workouts · goals & KPIs';
  String get nextAppointment   => _isEl ? 'Επόμενο ραντεβού'  : 'Next appointment';
  String upcomingAppointments(int n) => _isEl ? '$n επερχόμενα ραντεβού' : '$n upcoming appointments';
  String get confirmAttendance => _isEl ? 'Επιβεβαίωση'       : 'Confirm';
  String get reschedule        => _isEl ? 'Αλλαγή'            : 'Reschedule';
  String get sharePhoto        => _isEl ? 'Φωτό & Share'      : 'Photo & Share';
  String get gymLabel          => _isEl ? 'Γυμναστήριο'       : 'Gym';
  String get nutritionistLabel => _isEl ? 'Διατροφολόγος'     : 'Nutritionist';
  String get tipsLabelGym      => _isEl ? 'Tips προετοιμασίας' : 'Preparation tips';
  String get tipsTitleGym      => _isEl ? 'Έτοιμασου'         : 'Get ready';
  String get tipsLabelNutrition => _isEl ? 'Οδηγίες πριν τη συνεδρία' : 'Pre-session instructions';
  String get tipsTitleNutrition => _isEl ? 'Πριν τη συνεδρία' : 'Before the session';
  String get hideTips          => _isEl ? 'Κρύψε οδηγίες'    : 'Hide instructions';
  String withStaff(String name) => _isEl ? 'Με $name' : 'With $name';

  // ── Booking flow ─────────────────────────────────────────────────────────
  String get bookingFlowClosed    => _isEl ? 'Κλειστό'         : 'Closed';
  String get bookingFlowNoSlots   => _isEl ? 'Δεν υπάρχουν διαθέσιμες ώρες' : 'No available times';
  String get bookingFlowNoSlotsToday => _isEl ? 'Δεν υπάρχουν διαθέσιμες ώρες για σήμερα — δοκίμασε αργότερα ή άλλη ημέρα.' : 'No available times for today — try later or another day.';
  String get bookingFlowSelectMonth => _isEl ? 'Επίλεξε μήνα'  : 'Select month';
  String get bookingFlowFullSlotTitle => _isEl ? 'Πλήρης ώρα'  : 'Time slot full';
  String bookingFlowFullSlotBody(String time, String nextTime) => _isEl
      ? 'Η ώρα $time είναι πλήρης.\n\nΗ επόμενη διαθέσιμη είναι στις $nextTime. Θέλεις να κλείσεις εκεί ή να περιμένεις στη λίστα αναμονής αν αλλάξει κάτι;'
      : 'The $time slot is full.\n\nThe next available is at $nextTime. Would you like to book there or join the waitlist?';
  String bookingFlowFullSlotNoNext(String time) => _isEl
      ? 'Η ώρα $time είναι πλήρης και δεν υπάρχει άλλη διαθέσιμη ώρα αυτή την ημέρα.\n\nΘέλεις να μπεις στη λίστα αναμονής και να σε ενημερώσουμε αν ανοίξει θέση;'
      : 'The $time slot is full and there are no other available times today.\n\nJoin the waitlist and we\'ll notify you if a spot opens?';
  String get bookingFlowJoinWaitlist => _isEl ? 'Περίμενε στη λίστα' : 'Join waitlist';
  String bookingFlowBookNext(String time) => _isEl ? 'Κλείσε $time' : 'Book $time';
  String get bookingFlowWaitlistTitle => _isEl ? 'Λίστα αναμονής' : 'Waitlist';
  String bookingFlowClosedDay(String day) => _isEl ? 'Το γυμναστήριο είναι κλειστό κάθε $day.' : 'The gym is closed every $day.';
  String get bookingFlowLocation   => _isEl ? 'Τοποθεσία'                : 'Location';
  String get bookingFlowSelectLocationFirst => _isEl ? 'Επίλεξε πρώτα το γυμναστήριο για να δεις διαθέσιμες ημέρες και ώρες.' : 'Select a gym first to see available days and times.';
  String get bookingFlowOneDay     => _isEl ? 'Μία ημέρα'                : 'One day';
  String get bookingFlowRepeat     => _isEl ? 'Επανάληψη'                : 'Repeat';
  String get bookingFlowDate       => _isEl ? 'Ημερομηνία'               : 'Date';
  String get bookingFlowWeekdays   => _isEl ? 'Ημέρες εβδομάδας'         : 'Weekdays';
  String get bookingFlowPeriod     => _isEl ? 'Περίοδος'                 : 'Period';
  String get bookingFlowSpecificMonth => _isEl ? 'Συγκεκριμένος μήνας'   : 'Specific month';
  String get bookingFlowNextFourWeeks => _isEl ? 'Επόμενες 4 εβδ.'       : 'Next 4 weeks';
  String get bookingFlowTapToChangeMonth => _isEl ? 'Πάτα για αλλαγή μήνα' : 'Tap to change month';
  String get bookingFlowAvailableTimes => _isEl ? 'Διαθέσιμες ώρες'      : 'Available times';
  String get bookingFlowChangeTime => _isEl ? 'Αλλαγή ώρας'              : 'Change time';
  String get bookingFlowChange     => _isEl ? 'Αλλαγή'                   : 'Change';
  String bookingFlowWaitlistFor(String time) => _isEl ? 'Θα μπεις στη λίστα αναμονής για τις $time.' : 'You will join the waitlist for $time.';
  String bookingFlowBookAll(int n)  => _isEl ? 'Κλείσε όλες ($n)'        : 'Book all ($n)';
  String get bookingFlowWaitlistNotify => _isEl ? 'Θα σε ενημερώσουμε αν ανοίξει θέση στη λίστα αναμονής.' : 'We will notify you if a spot opens on the waitlist.';
  String bookingFlowBookNextAlt(String time) => _isEl ? 'Ή κλείσε την επόμενη διαθέσιμη ($time)' : 'Or book the next available ($time)';
  String get bookingFlowBulkTitle  => _isEl ? 'Επαναλαμβανόμενη κράτηση' : 'Recurring booking';
  String bookingFlowBulkConfirmBody(int n, String time) => _isEl ? 'Θα κλειστούν $n ραντεβού στις $time. Συνέχεια;' : '$n appointments will be booked at $time. Continue?';
  String get bookingFlowBulkDoneTitle => _isEl ? 'Ολοκληρώθηκε'          : 'Done';
  String bookingFlowBulkDoneBody(int n) => _isEl ? 'Κλείστηκαν $n ραντεβού.' : '$n appointments booked.';
  String get bookingFlowAlternativesTitle => _isEl ? 'Εναλλακτικές ώρες' : 'Alternative times';
  String get bookingFlowAlternativesBody => _isEl ? 'Μερικές ημέρες δεν ήταν διαθέσιμες. Θέλεις να κλείσεις τις προτεινόμενες εναλλακτικές;' : 'Some days were not available. Would you like to book the suggested alternatives?';
  String get bookingFlowBookSelected => _isEl ? 'Κλείσε επιλεγμένες'     : 'Book selected';
  String get bookingFlowSlotFull   => _isEl ? 'Πλήρες'                   : 'Full';
  String get bookingFlowStaffHint  => _isEl ? 'Πάτα για προφίλ · το ✓ για γρήγορη επιλογή' : 'Tap for profile · ✓ for quick select';
  String get bookingFlowStaffProfileHint => _isEl ? 'Πάτα για προφίλ και φωτογραφία' : 'Tap for profile and photo';
  String get bookingFlowUnlimitedSessions => _isEl ? 'Απεριόριστες συνεδρίες διαθέσιμες' : 'Unlimited sessions available';
  String bookingFlowSessionsAvailable(int n) => _isEl ? '$n διαθέσιμες συνεδρίες αυτόν τον μήνα' : '$n sessions available this month';
  String get bookingFlowNoSessionsAvailable => _isEl ? 'Δεν υπάρχουν διαθέσιμες συνεδρίες' : 'No sessions available';
  String get bookingFlowNoBulkDays => _isEl ? 'Δεν βρέθηκαν μελλοντικές ημέρες για κράτηση' : 'No future days found for booking';
  String bookingFlowBulkSummaryMonth(int n, String month, String time) => _isEl ? 'Θα κλειστούν $n ραντεβού τον $month στις $time' : '$n appointments will be booked in $month at $time';
  String bookingFlowBulkSummaryFour(int n, String time) => _isEl ? 'Θα κλειστούν $n ραντεβού στις $time (επόμενες 4 εβδ.)' : '$n appointments will be booked at $time (next 4 weeks)';
  // weekday labels for booking flow
  Map<int, String> get bookingFlowWeekdayLabels => _isEl
      ? {1: 'Δε', 2: 'Τρ', 3: 'Τε', 4: 'Πε', 5: 'Πα', 6: 'Σα', 7: 'Κυ'}
      : {1: 'Mo', 2: 'Tu', 3: 'We', 4: 'Th', 5: 'Fr', 6: 'Sa', 7: 'Su'};
  Map<int, String> get bookingFlowWeekdayFull => _isEl
      ? {1: 'Δευτέρα', 2: 'Τρίτη', 3: 'Τετάρτη', 4: 'Πέμπτη', 5: 'Παρασκευή', 6: 'Σάββατο', 7: 'Κυριακή'}
      : {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};

  // ── Booking success ───────────────────────────────────────────────────────
  String get bookingSuccessTitle    => _isEl ? 'Η κράτηση ολοκληρώθηκε!'    : 'Booking confirmed!';
  String get bookingSuccessSubtitle => _isEl ? 'Το ραντεβού σου καταχωρήθηκε με επιτυχία.' : 'Your appointment has been registered successfully.';
  String get bookingSuccessRedirect => _isEl ? 'Θα μεταφερθείς στις κρατήσεις σου σε λίγα δευτερόλεπτα' : 'You will be redirected to your bookings in a few seconds';
  String get bookingSuccessViewBtn  => _isEl ? 'Δες τις κρατήσεις μου'      : 'View my bookings';

  // ── Reschedule ───────────────────────────────────────────────────────────
  String get rescheduleTitle        => _isEl ? 'Αλλαγή ραντεβού'            : 'Reschedule appointment';
  String rescheduleCurrentDate(String date) => _isEl ? 'Τρέχον: $date'  : 'Current: $date';
  String get rescheduleNewDate      => _isEl ? 'Νέα ημερομηνία'             : 'New date';
  String get rescheduleNewTime      => _isEl ? 'Νέα ώρα'                    : 'New time';
  String get rescheduleNoSlots      => _isEl ? 'Δεν υπάρχουν διαθέσιμες ώρες αυτή την ημέρα' : 'No available times this day';
  String get rescheduleNoSlotsMsg   => _isEl ? 'Δεν υπάρχουν διαθέσιμες ώρες' : 'No available times';
  String get rescheduleSelectStaff  => _isEl ? 'Επίλεξε'                    : 'Select';
  String get rescheduleSave         => _isEl ? 'Αποθήκευση αλλαγής'         : 'Save change';
  String get rescheduleClosedDay    => _isEl ? 'Κλειστό'                    : 'Closed';

  // ── Completed bookings ────────────────────────────────────────────────────
  String get completedTitle         => _isEl ? 'Ολοκληρωμένα'              : 'Completed';
  String get completedHistory       => _isEl ? 'Ιστορικό'                  : 'History';
  String get completedGoalsBtn      => _isEl ? 'Στόχοι'                    : 'Goals';
  String get completedPendingSection => _isEl ? 'Εκκρεμεί επιβεβαίωση'    : 'Pending attendance';
  String get completedCompletedSection => _isEl ? 'Ολοκληρωμένες'         : 'Completed';
  String get completedNoneTitle     => _isEl ? 'Καμία ολοκληρωμένη προπόνηση' : 'No completed workouts';
  String get completedNoneSubtitle  => _isEl ? 'Όταν επιβεβαιώσεις παρουσία, θα εμφανίζεται εδώ.' : 'When you confirm attendance, it will appear here.';
  String get completedPerformance   => _isEl ? 'Επιδόσεις'                : 'Performance';
  String get completedThisMonth     => _isEl ? 'Αυτόν τον μήνα'           : 'This month';
  String get completedMonthGoal     => _isEl ? 'Στόχος μήνα'              : 'Monthly goal';
  String get completedPoints        => _isEl ? 'Πόντοι'                   : 'Points';
  String get completedGoalProgress  => _isEl ? 'Πρόοδος στόχου'           : 'Goal progress';
  String get completedAchieved      => _isEl ? 'Επιτεύχθηκε'             : 'Achieved';
  String completedStats(int thisMonth, int target, int total) => _isEl
      ? '$thisMonth / $target προπονήσεις · $total συνολικά ολοκληρωμένες'
      : '$thisMonth / $target workouts · $total completed in total';
  String get completedNoCheckin     => _isEl ? 'Χωρίς check-in'           : 'No check-in';
  String get completedFeedbackBtn   => _isEl ? 'Σχόλια & φωτό'            : 'Feedback & photo';
  String get completedViewTipsBtn   => _isEl ? 'Δες tips & share'         : 'View tips & share';
  String get completedLabel         => _isEl ? 'Ολοκληρωμένη'             : 'Completed';

  // ── Workout complete ──────────────────────────────────────────────────────
  String get workoutCompleteTitle    => _isEl ? 'Επιβεβαίωση παρουσίας'   : 'Attendance confirmation';
  String get workoutCompleteQuestion => _isEl ? 'Τελείωσες την προπόνηση;' : 'Did you finish your workout?';
  String get workoutCompleteEarlyMsg => _isEl ? 'Μπορείς να τραβήξεις φωτό και να κοινοποιήσεις τώρα. Η επιβεβαίωση παρουσίας ενεργοποιείται μετά το τέλος της προπόνησης.' : 'You can take a photo and share now. Attendance confirmation activates after the workout ends.';
  String get workoutCompleteCheckbox => _isEl ? 'Επιβεβαιώνω ότι πήγα στην προπόνηση' : 'I confirm I attended the workout';
  String get workoutCompleteAfterEnd => _isEl ? 'Διαθέσιμο μετά το τέλος της προπόνησης' : 'Available after the workout ends';
  String get workoutCompleteRequired => _isEl ? 'Απαιτείται για να καταχωρηθεί η συμμετοχή σου' : 'Required to register your attendance';
  String workoutCompleteGoalTarget(int n) => _isEl ? 'Στόχος $n προπονήσεις/μήνα' : 'Goal: $n workouts/month';
  String workoutCompleteSessions(int done, int target) => _isEl ? '$done / $target αυτόν τον μήνα' : '$done / $target this month';
  String get workoutCompleteGoalAchieved => _isEl ? '🎯 Συγχαρητήρια — πέτυχες τον στόχο σου!' : '🎯 Congratulations — you reached your goal!';
  String get workoutCompleteRecovery => _isEl ? 'Recovery & διατροφή' : 'Recovery & nutrition';
  String get workoutCompleteComment => _isEl ? 'Σχόλιο (προαιρετικό)' : 'Comment (optional)';
  String get workoutCompleteCamera  => _isEl ? 'Κάμερα'               : 'Camera';
  String get workoutCompleteSavePhoto => _isEl ? 'Αποθήκευση'          : 'Save';
  String get workoutCompletePhotoNote => _isEl ? 'Πάνω στη φωτό προστίθενται αυτόματα: πρόγραμμα, ημερομηνία, ώρα και logo του γυμναστηρίου.' : 'Added automatically to the photo: program, date, time and gym logo.';
  String get workoutCompleteBtn     => _isEl ? 'Επιβεβαίωση παρουσίας' : 'Confirm attendance';
  String get workoutCompletePhotoSaved => _isEl ? 'Η φωτογραφία αποθηκεύτηκε στη συλλογή σου' : 'Photo saved to your gallery';
  String workoutCompletePhotoError(String e) => _isEl ? 'Αποτυχία αποθήκευσης: $e' : 'Save failed: $e';
  String workoutCompleteConfirmedPoints(int points) => _isEl ? 'Επιβεβαιώθηκε! +$points πόντοι loyalty 🎉' : 'Confirmed! +$points loyalty points 🎉';
  String get workoutCompleteConfirmed => _isEl ? 'Επιβεβαιώθηκε!' : 'Confirmed!';
  String workoutCompleteCaloriesFromWatch(int cal) => _isEl ? ' · $cal kcal από ρολόι' : ' · $cal kcal from watch';

  // ── Workout metrics ───────────────────────────────────────────────────────
  String get metricsTitle           => _isEl ? 'Προπόνηση & Metrics'       : 'Workout & Metrics';
  String get metricsActivityDist    => _isEl ? 'Κατανομή δραστηριότητας'   : 'Activity distribution';
  String get metricsWeeklyCalories  => _isEl ? 'Εβδομαδιαίες θερμίδες'    : 'Weekly calories';
  String get metricsPerWorkout      => _isEl ? 'Ανά προπόνηση'             : 'Per workout';
  String get metricsDemoData        => _isEl ? 'Δεδομένα επίδειξης — συγχρόνισε το ρολόι ή ολοκλήρωσε κράτηση με health sync για πραγματικά metrics.' : 'Demo data — sync your watch or complete a booking with health sync for real metrics.';
  String get metricsSyncFromWatch   => _isEl ? 'Συγχρονισμένα από το ρολόι' : 'Synced from watch';
  String get metricsLoadRecent      => _isEl ? 'Φόρτωσε πρόσφατες προπονήσεις' : 'Load recent workouts';
  String get metricsSync            => _isEl ? 'Συγχρονισμός'              : 'Sync';
  String get metricsGoalTarget      => _isEl ? 'Στόχος προπονήσεων'        : 'Workout goal';
  String metricsDoneOfTarget(int done, int target) => _isEl ? '$done / $target αυτόν τον μήνα' : '$done / $target this month';
  String metricsCaloriesTarget(int cal) => _isEl ? 'Θερμίδες στόχος: ~$cal kcal' : 'Calorie goal: ~$cal kcal';
  String get metricsGoalAchieved    => _isEl ? 'Στόχος επιτεύχθηκε!'      : 'Goal achieved!';
  String get metricsWorkouts        => _isEl ? 'Προπονήσεις'               : 'Workouts';
  String get metricsMinutes         => _isEl ? 'Λεπτά'                     : 'Minutes';
  String get metricsCalories        => _isEl ? 'Θερμίδες'                  : 'Calories';
  String get metricsAvgHeartRate    => _isEl ? 'Μέσος σφυγμός'             : 'Avg heart rate';
  String get metricsNoData          => _isEl ? 'Δεν υπάρχουν δεδομένα δραστηριότητας' : 'No activity data';
  String get metricsNoHealthData    => _isEl ? 'Δεν βρέθηκαν προπονήσεις στο Apple Health' : 'No workouts found in Apple Health';
  String metricsLoadedFromWatch(int n) => _isEl ? 'Φορτώθηκαν $n προπονήσεις από το ρολόι' : 'Loaded $n workouts from watch';
  String get metricsDemoTooltip     => _isEl ? 'Demo δεδομένα'             : 'Demo data';
  String get metricsRefresh         => _isEl ? 'Ανανέωση'                  : 'Refresh';
  String get metricsActivity        => _isEl ? 'Δραστηριότητα'             : 'Activity';
  String get metricsDuration        => _isEl ? 'Διάρκεια'                  : 'Duration';
  String get metricsCaloriesKcal    => _isEl ? 'Θερμίδες'                  : 'Calories';
  String get metricsHeartRate       => _isEl ? 'Μέσος σφυγμός'             : 'Avg heart rate';
  String get metricsDistance        => _isEl ? 'Απόσταση'                  : 'Distance';
  String get metricsSource          => _isEl ? 'Πηγή'                      : 'Source';
  String get metricsSourceDemo      => _isEl ? 'Επίδειξη'                  : 'Demo';
  String minutesSuffix(int m)       => _isEl ? '$m λεπτά'                  : '$m minutes';

  // ── Workout programs ──────────────────────────────────────────────────────
  String get programsNoProgram     => _isEl ? 'Κανένα πρόγραμμα ακόμα'    : 'No program yet';
  String get programsNoAssigned    => _isEl ? 'Ο γυμναστής σου δεν έχει αναθέσει κάποιο\nπρόγραμμα άσκησης ακόμα.' : 'Your trainer has not assigned a workout program yet.';
  String exerciseCount(int n)      => _isEl ? '$n ασκήσεις'                : '$n exercises';
  String get exerciseSets          => _isEl ? 'Σετ'                        : 'Sets';
  String get exerciseReps          => _isEl ? 'Επαναλήψεις'                : 'Reps';
  String get exerciseDuration      => _isEl ? 'Διάρκεια'                   : 'Duration';
  String get exerciseRest          => _isEl ? 'Ανάπαυση'                   : 'Rest';
  String get exerciseInstructions  => _isEl ? 'Οδηγίες'                    : 'Instructions';
  String get exerciseTrainerNotes  => _isEl ? 'Σημειώσεις γυμναστή'       : 'Trainer notes';
  String get programsUserNotFound  => _isEl ? 'Δεν βρέθηκε χρήστης.'      : 'User not found.';

  // ── Goals ────────────────────────────────────────────────────────────────
  String get goalsTitle            => _isEl ? 'Στόχοι'                    : 'Goals';
  String get goalsFitnessSection   => _isEl ? 'Φυσική κατάσταση'          : 'Fitness';
  String get goalsFitnessDesc      => _isEl ? 'Ορίσε τον στόχο σου (π.χ. απώλεια βάρους) και καταχώρησε το τρέχον και το επιθυμητό βάρος.' : 'Set your goal (e.g. weight loss) and enter your current and target weight.';
  String get goalsGoalType         => _isEl ? 'Τύπος στόχου'              : 'Goal type';
  String get goalsCurrentWeight    => _isEl ? 'Τρέχον βάρος (kg)'         : 'Current weight (kg)';
  String get goalsTargetWeight     => _isEl ? 'Στόχος βάρους (kg)'        : 'Target weight (kg)';
  String goalsWeightDistance(double d) => _isEl ? 'Απόσταση από στόχο: ${d.toStringAsFixed(1)} kg' : 'Distance from goal: ${d.toStringAsFixed(1)} kg';
  String get goalsSaveDetails      => _isEl ? 'Αποθήκευση στοιχείων'      : 'Save details';
  String get goalsWorkoutSection   => _isEl ? 'Προπόνηση & πόντοι'        : 'Workout & points';
  String get goalsLoyaltyPoints    => _isEl ? 'Loyalty πόντοι'            : 'Loyalty points';
  String get goalsMonthProgress    => _isEl ? 'Πρόοδος μήνα'              : 'Monthly progress';
  String goalsSessionsProgress(int done, int target) => _isEl ? '$done / $target προπονήσεις' : '$done / $target workouts';
  String get goalsMonthlyGoal      => _isEl ? 'Μηνιαίος στόχος προπονήσεων' : 'Monthly workout goal';
  String goalsPerMonth(int n)      => _isEl ? '$n/μήνα'                   : '$n/month';
  String get goalsSaveWorkoutGoal  => _isEl ? 'Αποθήκευση στόχου προπονήσεων' : 'Save workout goal';
  String get goalsWeightRange      => _isEl ? 'Το βάρος πρέπει να είναι μεταξύ 0 και 500 kg' : 'Weight must be between 0 and 500 kg';
  String get goalsTargetWeightRange => _isEl ? 'Ο στόχος βάρους πρέπει να είναι μεταξύ 0 και 500 kg' : 'Target weight must be between 0 and 500 kg';
  String get goalsSaved            => _isEl ? 'Τα στοιχεία σου αποθηκεύτηκαν' : 'Your details were saved';
  String get goalsMonthlyGoalSaved => _isEl ? 'Ο μηνιαίος στόχος ενημερώθηκε' : 'Monthly goal updated';

  // ── Services ─────────────────────────────────────────────────────────────
  String get servicesNoPackages    => _isEl ? 'Δεν έχεις ενεργά πακέτα'   : 'No active packages';
  String get servicesNoPackagesSub => _isEl ? 'Επικοινώνησε με το γυμναστήριο για εγγραφή σε πρόγραμμα.' : 'Contact the gym to sign up for a program.';
  String get servicesUnlimited     => _isEl ? 'Απεριόριστο'                : 'Unlimited';
  String get servicesNoCredits     => _isEl ? 'Χωρίς υπόλοιπο'            : 'No balance';
  String servicesCredits(int n)    => _isEl ? '$n συνεδρίες'               : '$n sessions';
  String get servicesPendingNutrition => _isEl ? 'Αίτημα σε αναμονή — επιβεβαίωση από διατροφολόγο' : 'Request pending — awaiting nutritionist confirmation';
  String get servicesConfirmedNutrition => _isEl ? 'Επιβεβαιωμένο ραντεβού με διατροφολόγο' : 'Confirmed appointment with nutritionist';
  String get servicesUnlimitedNutrition => _isEl ? 'Μέτρηση / συνεδρία — απεριόριστες επισκέψεις' : 'Measurement / session — unlimited visits';
  String servicesNutritionCredits(int n) => _isEl ? '$n επισκέψεις διαθέσιμες' : '$n visits available';
  String get servicesNoNutritionist => _isEl ? 'Δεν υπάρχει διαθέσιμος διατροφολόγος αυτή τη στιγμή' : 'No nutritionist available at the moment';
  String get servicesContactForVisits => _isEl ? 'Επικοινώνησε με το γυμναστήριο για επισκέψεις' : 'Contact the gym for visits';
  String servicesRenewal(String date) => _isEl ? 'Ανανέωση $date'         : 'Renewal $date';
  String get servicesBook          => _isEl ? 'Κράτηση'                   : 'Book';

  // ── Credits / Packages ───────────────────────────────────────────────────
  String get creditsNoPackages     => _isEl ? 'Δεν έχεις ενεργά πακέτα'   : 'No active packages';
  String get creditsCancelTitle    => _isEl ? 'Διακοπή συνδρομής'         : 'Cancel subscription';
  String get creditsCancelQuestion => _isEl ? 'Θέλεις να διακόψεις τη συνδρομή σου;' : 'Do you want to cancel your subscription?';
  String get creditsCancelReason   => _isEl ? 'Λόγος (προαιρετικό)'       : 'Reason (optional)';
  String get creditsCancelReasonHint => _isEl ? 'π.χ. Μετακόμιση'         : 'e.g. Moving away';
  String get creditsCancelBtn      => _isEl ? 'Διακοπή'                   : 'Cancel subscription';
  String get creditsCancelled      => _isEl ? 'Η συνδρομή διακόπηκε'      : 'Subscription cancelled';
  String get creditsMealPlan       => _isEl ? 'Πλάνο γευμάτων'            : 'Meal plan';
  String get creditsMeasurements   => _isEl ? 'Μετρήσεις'                 : 'Measurements';
  String get creditsFoodDiary      => _isEl ? 'Ημερολόγιο διατροφής'      : 'Food diary';
  String get creditsNutritionVisits => _isEl ? 'Επισκέψεις διατροφολόγου' : 'Nutritionist visits';
  String creditsNutritionVisitsCount(int n) => _isEl ? '$n επισκέψεις διατροφολόγου' : '$n nutritionist visits';
  String get creditsNutritionProgram => _isEl ? 'Πρόγραμμα διατροφής'     : 'Nutrition program';
  String get creditsNutritionVisitsSect => _isEl ? 'Επισκέψεις διατροφολόγου' : 'Nutritionist visits';
  String get creditsGenericPackage => _isEl ? 'Γενικό πακέτο'             : 'General package';
  String creditsGracePeriod(int days) => 'η συνδρομή έληξε — περίοδος χάριτος $days ημέρες. Ανένεωσε για να συνεχίσεις.';
  String creditsGracePeriodEn(int days)   => 'subscription expired — $days day grace period. Renew to continue.';
  String get creditsActivePlan     => _isEl ? 'Ενεργό πρόγραμμα διατροφής' : 'Active nutrition program';
  String get creditsSessionsBalance => _isEl ? 'Υπόλοιπο συνεδριών'       : 'Session balance';
  String get creditsUnlimitedSessions => _isEl ? 'Απεριόριστες'           : 'Unlimited';
  String creditsSessionsThisMonth(int rem, int perPeriod) => _isEl ? '$rem / $perPeriod αυτόν τον μήνα' : '$rem / $perPeriod this month';
  String get creditsUnlimitedSessionsLabel => _isEl ? 'Απεριόριστες συνεδρίες' : 'Unlimited sessions';
  String get creditsBalance        => _isEl ? 'Υπόλοιπο'                  : 'Balance';
  String get creditsStart          => _isEl ? 'Έναρξη'                    : 'Start';
  String get creditsNextRenewal    => _isEl ? 'Επόμενη ανανέωση'          : 'Next renewal';
  String get creditsExpiry         => _isEl ? 'Λήξη'                      : 'Expiry';
  String get creditsLastPayment    => _isEl ? 'Τελευταία πληρωμή'         : 'Last payment';
  String get creditsPeriod         => _isEl ? 'Περίοδος'                  : 'Period';
  String get creditsPrice          => _isEl ? 'Τιμή'                      : 'Price';
  String get creditsPeriodMonthly  => _isEl ? 'Μηνιαίο'                   : 'Monthly';
  String get creditsPeriodYearly   => _isEl ? 'Ετήσιο'                    : 'Yearly';
  String get creditsPeriodWeekly   => _isEl ? 'Εβδομαδιαίο'               : 'Weekly';
  String get creditsPendingAppt    => _isEl ? 'Έχεις αίτημα κράτησης σε αναμονή επιβεβαίωσης.' : 'You have a booking request awaiting confirmation.';
  String get creditsConfirmedAppt  => _isEl ? 'Έχεις επιβεβαιωμένο ραντεβού με τον διατροφολόγο.' : 'You have a confirmed appointment with the nutritionist.';
  String get creditsBookNutritionist => _isEl ? 'Κράτηση διατροφολόγου'   : 'Book nutritionist';
  String get creditsNoNutritionist  => _isEl ? 'Δεν υπάρχει διαθέσιμος διατροφολόγος' : 'No nutritionist available';
  String get creditsCancelSubscription => _isEl ? 'Διακοπή συνδρομής'     : 'Cancel subscription';
  String creditsPendingPayment(String amount) => _isEl ? 'Εκκρεμής πληρωμή $amount' : 'Pending payment $amount';
  String creditsPayBtn(String amount) => _isEl ? 'Πλήρωσε $amount'    : 'Pay $amount';
  String creditsPaymentLabel(String amount) => _isEl ? 'Πληρωμή · $amount' : 'Payment · $amount';

  // ── Payments ─────────────────────────────────────────────────────────────
  String get paymentsTitle         => _isEl ? 'Οι πληρωμές μου'           : 'My payments';
  String get paymentsBalance       => _isEl ? 'Υπόλοιπο προς πληρωμή'    : 'Balance due';
  String get paymentsNoEntries     => _isEl ? 'Δεν υπάρχουν καταχωρήσεις' : 'No entries';
  String get paymentsNoEntriesSub  => _isEl ? 'Ο διαχειριστής θα προσθέσει τις πληρωμές σου εδώ.' : 'The admin will add your payments here.';
  String get paymentsDefaultLabel  => _isEl ? 'Πληρωμή'                   : 'Payment';
  String paymentsTotalPaid(String total, String paid) => _isEl ? 'Σύνολο: $total · Πληρώθηκε: $paid' : 'Total: $total · Paid: $paid';
  String paymentsBalance2(String amount) => _isEl ? 'Υπόλοιπο: $amount'   : 'Balance: $amount';
  String paymentsPayBtn(String amount) => _isEl ? 'Πλήρωσε $amount'       : 'Pay $amount';

  // ── Notifications ─────────────────────────────────────────────────────────
  String get notificationsTitle    => _isEl ? 'Ειδοποιήσεις'              : 'Notifications';
  String get notificationsEmpty    => _isEl ? 'Δεν υπάρχουν ειδοποιήσεις' : 'No notifications';
  String get notificationsMarkRead => _isEl ? 'Όλα διαβαστέντα'           : 'Mark all read';
  String get notificationTapToRead => _isEl ? 'Πάτα για ανάγνωση'        : 'Tap to read';
  String get notificationDefault   => _isEl ? 'Ειδοποίηση'               : 'Notification';
  String notificationsMinutesAgo(int m) => _isEl ? 'Πριν $m λεπτά'       : '$m min ago';
  String notificationsHoursAgo(int h)   => _isEl ? 'Πριν $h ώρες'        : '$h hr ago';
  String notificationsDaysAgo(int d)    => _isEl ? 'Πριν $d μέρες'       : '$d days ago';
  String get notificationsJustNow  => _isEl ? 'Μόλις τώρα'               : 'Just now';
  String get notificationsYesterday => _isEl ? 'Χθες'                     : 'Yesterday';

  // ── Messages ─────────────────────────────────────────────────────────────
  String get messagesTitle         => _isEl ? 'Μηνύματα'                  : 'Messages';
  String get messagesNewConversation => _isEl ? 'Νέα συνομιλία'           : 'New conversation';
  String get messagesNewConversationTooltip => _isEl ? 'Νέα συνομιλία'    : 'New conversation';
  String get messagesStartConversation => _isEl ? 'Ξεκίνα συνομιλία'      : 'Start conversation';
  String get messagesNoContacts    => _isEl ? 'Δεν υπάρχουν διαθέσιμες επαφές.\nΕπικοινώνησε με τη διαχείριση του γυμναστηρίου.' : 'No available contacts.\nContact gym management.';
  String get messagesWriteHint     => _isEl ? 'Γράψε μήνυμα...'           : 'Write a message...';
  String get messagesFailedImage   => _isEl ? 'Αποτυχία αποστολής εικόνας. Έλεγξε τη σύνδεση με το Wi‑Fi.' : 'Failed to send image. Check your Wi‑Fi connection.';
  String get messagesDefaultThread => _isEl ? 'Συνομιλία'                 : 'Conversation';

  // ── Community ─────────────────────────────────────────────────────────────
  String get communityTitle        => _isEl ? 'Κοινότητα'                 : 'Community';
  String get communityNoPosts      => _isEl ? 'Δεν υπάρχουν αναρτήσεις ακόμα' : 'No posts yet';
  String get communityFirstPost    => _isEl ? 'Πρώτη ανάρτηση'            : 'First post';
  String get communityLoadMore     => _isEl ? 'Περισσότερα'                : 'Load more';
  String get communityNewPost      => _isEl ? 'Ανάρτηση'                  : 'Post';
  String get communityDeleteTitle  => _isEl ? 'Διαγραφή;'                 : 'Delete?';
  String get communityDeletePost   => _isEl ? 'Να διαγραφεί η ανάρτηση;' : 'Delete this post?';
  String get communityDeleteComment => _isEl ? 'Να διαγραφεί το σχόλιο;'  : 'Delete this comment?';
  String get communityPinned       => _isEl ? 'Καρφιτσωμένο'              : 'Pinned';
  String get communityDeleteAction => _isEl ? 'Διαγραφή'                  : 'Delete';
  String communityMoreComments(int n) => _isEl ? '+ $n ακόμα σχόλια'  : '+ $n more comments';
  String get communityJustNow      => _isEl ? 'μόλις τώρα'                : 'just now';
  String communityMinutesAgo(int m) => _isEl ? '$m λ. πριν'               : '${m}m ago';
  String communityHoursAgo(int h)   => _isEl ? '$h ω. πριν'               : '${h}h ago';
  String get communityUnknownAuthor => _isEl ? 'Άγνωστος'                 : 'Unknown';
  String get communityContactWith  => _isEl ? 'Επικοινωνία με:'           : 'Contact:';
  String get communityNoContacts   => _isEl ? 'Δεν βρέθηκαν διαθέσιμες επαφές' : 'No available contacts found';
  String get communityComments     => _isEl ? 'Σχόλια'                    : 'Comments';
  String get communityMessageTooltip => _isEl ? 'Μήνυμα'                  : 'Message';
  String get communityNewPostTooltip => _isEl ? 'Νέα ανάρτηση'            : 'New post';
  String get communityRoleAdmin    => _isEl ? 'Διαχειριστής'              : 'Admin';
  String get communityRoleSecretary => _isEl ? 'Γραμματεία'               : 'Secretary';
  String get communityRoleReceptionist => _isEl ? 'Ρεσεψιόν'              : 'Reception';
  String communityError(String e) => _isEl ? 'Σφάλμα: $e'             : 'Error: $e';

  // ── Nutrition ─────────────────────────────────────────────────────────────
  String get nutritionPrevDay      => _isEl ? 'Προηγούμενη ημέρα'         : 'Previous day';
  String get nutritionNextDay      => _isEl ? 'Επόμενη ημέρα'             : 'Next day';
  String get nutritionCalendar     => _isEl ? 'Ημερολόγιο'                : 'Calendar';
  String get nutritionGoToToday    => _isEl ? 'Πήγαινε στο σήμερα'        : 'Go to today';
  String get nutritionSelectDay    => _isEl ? 'Επίλεξε ημέρα'             : 'Select day';
  String nutritionPlanFrom(String date) => _isEl ? 'Πρόγραμμα από $date' : 'Plan from $date';
  String get nutritionShoppingList => _isEl ? 'Λίστα αγορών'              : 'Shopping list';
  String get nutritionList         => _isEl ? 'Λίστα'                     : 'List';
  String get nutritionBreakfastNow => _isEl ? 'Πρωινό τώρα'               : 'Breakfast now';
  String get nutritionLunchNow     => _isEl ? 'Μεσημεριανό τώρα'          : 'Lunch now';
  String get nutritionDinnerNow    => _isEl ? 'Βραδινό τώρα'              : 'Dinner now';
  String get nutritionSnackNow     => _isEl ? 'Σνακ τώρα'                 : 'Snack now';
  String get nutritionNow2         => _isEl ? 'Τώρα'                      : 'Now';
  String get nutritionNoPlanYet    => _isEl ? 'Το πρόγραμμα διατροφής έρχεται σύντομα' : 'Nutrition plan coming soon';
  String get nutritionNoPlanBody   => _isEl ? 'Ο διατροφολόγος σου θα σου στείλει το εβδομαδιαίο πρόγραμμα. Μέχρι τότε μπορείς να καταγράφεις τα γεύματά σου.' : 'Your nutritionist will send you the weekly plan. In the meantime you can log your meals.';
  String get nutritionNoPlanDay    => _isEl ? 'Δεν έχει οριστεί πρόγραμμα για αυτή την ημέρα. Μπορείς να καταγράψεις τι έφαγες.' : 'No plan set for this day. You can log what you ate.';
  String get nutritionNoPlanMeal   => _isEl ? 'Δεν έχει οριστεί πρόγραμμα για αυτό το γεύμα.' : 'No plan set for this meal.';
  String get nutritionWeightKg     => _isEl ? 'Βάρος (kg)'                : 'Weight (kg)';
  String get nutritionTargetKg     => _isEl ? 'Στόχος (kg)'               : 'Target (kg)';
  String get nutritionHeightCm     => _isEl ? 'Ύψος (cm)'                 : 'Height (cm)';
  String get nutritionBodyFat      => _isEl ? 'Λίπος (%)'                 : 'Body fat (%)';
  String get nutritionSaveGoals    => _isEl ? 'Αποθήκευση στόχων'         : 'Save goals';
  String get nutritionSavingGoals  => _isEl ? 'Αποθήκευση...'             : 'Saving...';
  String get nutritionSaved        => _isEl ? 'Η μέτρηση αποθηκεύτηκε'   : 'Measurement saved';
  String get nutritionGoalsSaved   => _isEl ? 'Οι στόχοι αποθηκεύτηκαν'  : 'Goals saved';
  String get nutritionLogged       => _isEl ? 'Καταγράφηκε — ο διατροφολόγος θα το δει' : 'Logged — your nutritionist will see it';
  String get nutritionWriteFirst   => _isEl ? 'Γράψε τι έφαγες'           : 'Write what you ate';
  String get nutritionWhatAte      => _isEl ? 'Τι έφαγες;'                : 'What did you eat?';
  String get nutritionWhatAteHint  => _isEl ? 'π.χ. Σαλάτα αντί για κοτόπουλο' : 'e.g. Salad instead of chicken';
  String get nutritionCamera       => _isEl ? 'Κάμερα'                    : 'Camera';
  String get nutritionLog          => _isEl ? 'Καταγραφή'                 : 'Log';
  String get nutritionSaving       => _isEl ? 'Αποθήκευση...'             : 'Saving...';
  String get nutritionAteIt        => _isEl ? 'Το έφαγα'                  : 'I ate it';
  String get nutritionOtherFood    => _isEl ? 'Έφαγα κάτι άλλο'           : 'I ate something else';
  String get nutritionCloseOther   => _isEl ? 'Κλείσιμο'                  : 'Close';
  String get nutritionCopyList     => _isEl ? 'Αντιγραφή λίστας'          : 'Copy list';
  String get nutritionCopied       => _isEl ? 'Η λίστα αντιγράφηκε στο clipboard' : 'List copied to clipboard';
  String get nutritionShoppingNote => _isEl ? 'Προτάσεις σε πρακτικές συσκευασίες (π.χ. 450 ml → 1 λίτρο).' : 'Suggested in practical package sizes (e.g. 450 ml → 1 litre).';
  String get nutritionShoppingNoList => _isEl ? 'Η λίστα θα εμφανιστεί μόλις ο διατροφολόγος σου στείλει το πρόγραμμα.' : 'The list will appear once your nutritionist sends the plan.';
  String get nutritionNoIngredients => _isEl ? 'Ο διατροφολόγος δεν έχει ορίσει υλικά ακόμα.' : 'The nutritionist has not set ingredients yet.';
  String nutritionNeedAmount(String amount, String unit) => _isEl ? 'Χρειάζεσαι $amount $unit' : 'You need $amount $unit';

  static const List<String> dayNamesEl = ['', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];
  static const List<String> dayNamesEn = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  List<String> get dayNames => _isEl ? dayNamesEl : dayNamesEn;

  // ── Marketplace ───────────────────────────────────────────────────────────
  String get marketplaceAddedToCart => _isEl ? 'Προστέθηκε στο καλάθι'    : 'Added to cart';
  String marketplaceCartBtn(String price) => _isEl ? 'Καλάθι →' : 'Cart →';
  String get marketplaceCartBtnLabel => _isEl ? 'Καλάθι →'                : 'Cart →';
  String get marketplaceOrderSuccess => _isEl ? 'Παραγγελία καταχωρήθηκε! 🎉' : 'Order placed! 🎉';
  String get marketplaceOrderSuccessBody => _isEl ? 'Θα λάβεις ειδοποίηση όταν είναι έτοιμη.' : 'You will be notified when it\'s ready.';
  String get marketplaceMyOrders   => _isEl ? 'Οι παραγγελίες μου'        : 'My orders';
  String get marketplaceEmpty      => _isEl ? 'Δεν υπάρχουν προϊόντα'     : 'No products';
  String get marketplaceEmptySub   => _isEl ? 'Το γυμναστήριο δεν έχει ανεβάσει προϊόντα ακόμα.' : 'The gym has not uploaded any products yet.';
  String get marketplaceOutOfStock => _isEl ? 'Εξαντλήθηκε'               : 'Out of stock';
  String get marketplaceInfo       => _isEl ? 'Πληροφορίες'               : 'Information';
  String get marketplaceStock      => _isEl ? 'Απόθεμα'                   : 'Stock';
  String marketplaceStockUnits(int n) => _isEl ? '$n τεμ.'            : '$n pcs';
  String get marketplaceWeight     => _isEl ? 'Βάρος'                     : 'Weight';
  String get marketplaceIngredients => _isEl ? 'Συστατικά'                : 'Ingredients';
  String get marketplaceUsage      => _isEl ? 'Οδηγίες χρήσης'            : 'Usage instructions';
  String get marketplaceNotes      => _isEl ? 'Σημειώσεις'                : 'Notes';
  String get marketplaceAddToCart  => _isEl ? 'Προσθήκη στο καλάθι'       : 'Add to cart';
  String marketplaceAddWithPrice(String price) => _isEl ? 'Προσθήκη · $price' : 'Add · $price';
  String get marketplacePayCash    => _isEl ? 'Μετρητά'                   : 'Cash';
  String get marketplacePayCard    => _isEl ? 'Κάρτα'                     : 'Card';
  String get marketplacePayPickup  => _isEl ? 'Παραλαβή από κατάστημα'    : 'Store pickup';
  String get marketplacePayStripe  => _isEl ? 'Online πληρωμή'            : 'Online payment';
  String get marketplacePayBank    => _isEl ? 'Τραπεζική μεταφορά'        : 'Bank transfer';
  String get marketplaceTotal      => _isEl ? 'Σύνολο'                    : 'Total';
  String marketplaceContinue(String price) => _isEl ? 'Συνέχεια · $price' : 'Continue · $price';
  String get marketplaceContactInfo => _isEl ? 'Στοιχεία επικοινωνίας'    : 'Contact details';
  String get marketplaceFullName   => _isEl ? 'Ονοματεπώνυμο'             : 'Full name';
  String get marketplacePhoneField => _isEl ? 'Τηλέφωνο'                  : 'Phone';
  String get marketplaceDelivery   => _isEl ? 'Τρόπος παραλαβής'          : 'Delivery method';
  String get marketplacePickupLabel => _isEl ? 'Από το κατάστημα'         : 'From store';
  String get marketplaceShipLabel  => _isEl ? 'Αποστολή'                  : 'Delivery';
  String get marketplaceShipAddress => _isEl ? 'Διεύθυνση αποστολής'      : 'Shipping address';
  String get marketplacePaymentMethod => _isEl ? 'Τρόπος πληρωμής'        : 'Payment method';
  String get marketplaceOrderNotes => _isEl ? 'Σημειώσεις παραγγελίας (προαιρετικό)' : 'Order notes (optional)';
  String get marketplaceOrderTotal => _isEl ? 'Σύνολο παραγγελίας'        : 'Order total';
  String marketplaceSubmitBtn(String price) => _isEl ? 'Υποβολή παραγγελίας' : 'Place order';
  String get marketplaceSubmitting => _isEl ? 'Υποβολή...'                : 'Submitting...';
  String get marketplaceSelectPayment => _isEl ? 'Επίλεξε τρόπο πληρωμής' : 'Select a payment method';

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profileQrTitle        => _isEl ? 'Το QR μου'                 : 'My QR';
  String get profileQrSubtitle     => _isEl ? 'Δείξε το στον scanner εισόδου' : 'Show it to the entry scanner';
  String get profileGoals          => _isEl ? 'Στόχοι'                    : 'Goals';
  String profileGoalsSubtitle(String s) => _isEl ? (s.isEmpty ? 'Βάρος, στόχος & προπονήσεις' : s) : (s.isEmpty ? 'Weight, goal & workouts' : s);
  String get profileMetrics        => _isEl ? 'Προπόνηση & Metrics'       : 'Workout & Metrics';
  String get profileMetricsSubtitle => _isEl ? 'Ρολόι, θερμίδες & στόχοι' : 'Watch, calories & goals';
  String profileBiometricLogin(String label) => _isEl ? 'Είσοδος με $label' : 'Sign in with $label';
  String profileBiometricSubtitle(String label) => _isEl ? 'Μετά το logout, είσοδος με $label χωρίς κωδικό' : 'After logout, sign in with $label without a PIN';
  String get profileBiometricFailed => _isEl ? 'Δεν ενεργοποιήθηκε η βιομετρική είσοδος' : 'Biometric login could not be enabled';
  String get profilePayments       => _isEl ? 'Οι πληρωμές μου'           : 'My payments';
  String get profilePaymentsSubtitle => _isEl ? 'Ιστορικό & εκκρεμότητες' : 'History & pending';
  String get profileNotifications  => _isEl ? 'Ειδοποιήσεις'              : 'Notifications';
  String get profileNotifSubtitle  => _isEl ? 'Ανακοινώσεις & υπενθυμίσεις' : 'Announcements & reminders';
  String get profileMessages       => _isEl ? 'Μηνύματα'                  : 'Messages';
  String get profileMessagesSubtitle => _isEl ? 'Επικοινωνία με το γυμναστήριο' : 'Communication with the gym';
  String get profilePhone          => _isEl ? 'Τηλέφωνο'                  : 'Phone';
  String get profileLogout         => _isEl ? 'Αποσύνδεση'                : 'Logout';
  String profileTargetWeight(double tw) => _isEl ? 'στόχος ${tw.toStringAsFixed(1)} kg' : 'target ${tw.toStringAsFixed(1)} kg';

  // ── Staff home ────────────────────────────────────────────────────────────
  String get staffScheduleTab      => _isEl ? 'Πρόγραμμα'                 : 'Schedule';
  String get staffCommunityTab     => _isEl ? 'Κοινότητα'                 : 'Community';
  String get staffLeavesTab        => _isEl ? 'Άδειες'                    : 'Leaves';
  String get staffProfileTab       => _isEl ? 'Προφίλ'                    : 'Profile';

  // ── Staff schedule ────────────────────────────────────────────────────────
  String get staffScheduleToday    => _isEl ? 'Σήμερα'                    : 'Today';
  String get staffScheduleNoBookings => _isEl ? 'Δεν υπάρχουν κρατήσεις' : 'No bookings';
  String get staffScheduleNoneToday => _isEl ? 'Δεν έχεις κρατήσεις σήμερα.' : 'You have no bookings today.';
  String get staffScheduleNoneDay  => _isEl ? 'Δεν υπάρχουν κρατήσεις αυτή την ημέρα.' : 'No bookings for this day.';
  String get staffScheduleTrial    => _isEl ? 'Δοκιμαστικό'               : 'Trial';
  String get staffScheduleConfirmAttendance => _isEl ? 'Επιβεβαίωση παρουσίας' : 'Confirm attendance';
  String get staffScheduleConfirmed => _isEl ? 'Παρουσία επιβεβαιωμένη'   : 'Attendance confirmed';

  // ── Staff leaves ──────────────────────────────────────────────────────────
  String get staffLeavesCancelTitle => _isEl ? 'Ακύρωση αιτήματος;'       : 'Cancel request?';
  String get staffLeavesCancelBody  => _isEl ? 'Το αίτημα άδειας θα ακυρωθεί.' : 'The leave request will be cancelled.';
  String get staffLeavesCancelBtn   => _isEl ? 'Ακύρωση'                  : 'Cancel';
  String get staffLeavesStatusApproved => _isEl ? 'Εγκρίθηκε'             : 'Approved';
  String get staffLeavesStatusRejected => _isEl ? 'Απορρίφθηκε'           : 'Rejected';
  String get staffLeavesStatusPending  => _isEl ? 'Σε αναμονή'            : 'Pending';
  String get staffLeavesBalance    => _isEl ? 'Υπόλοιπο αδειών'           : 'Leave balance';
  String staffLeavesOf(int remaining, int total) => _isEl ? '$remaining από $total μέρες' : '$remaining of $total days';
  String get staffLeavesUsed       => _isEl ? 'Χρησιμοποιήθηκαν'         : 'Used';
  String staffLeavesDays(int n)    => _isEl ? '$n μέρες'                  : '$n days';
  String get staffLeavesEmpty      => _isEl ? 'Δεν υπάρχουν άδειες'      : 'No leave requests';
  String get staffLeavesEmptySub   => _isEl ? 'Πάτα + για να στείλεις αίτημα άδειας.' : 'Tap + to send a leave request.';
  String get staffLeavesDaySuffix  => _isEl ? 'μέρα'                      : 'day';
  String get staffLeavesDaysSuffix => _isEl ? 'μέρες'                     : 'days';
  String get staffLeavesCancelAction => _isEl ? 'Ακύρωση αιτήματος'      : 'Cancel request';
  String get staffLeavesSelectDate => _isEl ? 'Επιλογή ημερομηνιών'       : 'Select dates';
  String get staffLeavesEnterDate  => _isEl ? 'Επιλέξτε ημερομηνία'       : 'Select a date';
  String get staffLeavesNewRequest => _isEl ? 'Νέο αίτημα άδειας'         : 'New leave request';
  String get staffLeavesNewRequestSub => _isEl ? 'Το αίτημα θα σταλεί για έγκριση από τον διαχειριστή.' : 'The request will be sent for admin approval.';
  String get staffLeavesReason     => _isEl ? 'Αιτία (προαιρετικά)'       : 'Reason (optional)';
  String get staffLeavesSend       => _isEl ? 'Αποστολή αιτήματος'        : 'Send request';

  // ── Staff profile ─────────────────────────────────────────────────────────
  String get staffProfileGym       => _isEl ? 'Γυμναστήριο'               : 'Gym';
  String get staffProfileBio       => _isEl ? 'Βιογραφικό'                : 'Bio';
  String get staffProfileLogout    => _isEl ? 'Αποσύνδεση'                : 'Logout';
  String get staffProfileLogoutTitle => _isEl ? 'Αποσύνδεση;'             : 'Logout?';
  String staffProfileLogoutBody(String gymName) => _isEl ? 'Θα αποσυνδεθείς από το $gymName.' : 'You will be logged out of $gymName.';

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get onboardingSlide1Title => _isEl ? 'Κρατήσεις\nμε ένα tap'     : 'Bookings\nwith one tap';
  String get onboardingSlide1Body  => _isEl ? 'Κλείσε θέση σε κάθε ομαδικό μάθημα,\nδες το πρόγραμμα και διαχειρίσου\nτις συνεδρίες σου εύκολα.' : 'Reserve a spot in every group class,\nview the schedule and manage\nyour sessions easily.';
  String get onboardingSlide2Title => _isEl ? 'Παρακολούθησε\nτην πρόοδό σου' : 'Track\nyour progress';
  String get onboardingSlide2Body  => _isEl ? 'Δες αναλυτικά stats προπόνησης,\nπαρακολούθησε το σώμα σου\nκαι μείνε στον στόχο σου.' : 'See detailed workout stats,\ntrack your body\nand stay on track.';
  String get onboardingSlide3Title => _isEl ? 'Marketplace\n& Παραγγελίες' : 'Marketplace\n& Orders';
  String get onboardingSlide3Body  => _isEl ? 'Αγόρασε supplements και προϊόντα\nάμεσα από το app και παρακολούθησε\nτην πορεία της παραγγελίας σου.' : 'Buy supplements and products\ndirectly from the app and track\nthe progress of your order.';
}

/// Thin bridge so AppStrings.of() doesn't need BuildContext.
class _LanguageServiceBridge {
  static String code = 'el';
}

void updateLanguageBridge(String code) {
  _LanguageServiceBridge.code = code;
}
