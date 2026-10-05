import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Must match CFBundleURLSchemes (iOS) and the Android intent-filter.
const stripeReturnScheme = 'omniplex';

/// Light card form. A dark sheet on Android paints the typed digits and the
/// cursor black, so the field looks empty and the cursor cannot be placed.
const cardPaymentAppearance = PaymentSheetAppearance(
  colors: PaymentSheetAppearanceColors(
    primary: Color(0xFF111111),
    background: Color(0xFFFFFFFF),
    componentBackground: Color(0xFFF4F4F5),
    componentBorder: Color(0xFFD0D0D4),
    componentDivider: Color(0xFFE4E4E7),
    primaryText: Color(0xFF111111),
    secondaryText: Color(0xFF3F3F46),
    componentText: Color(0xFF111111),
    placeholderText: Color(0xFF71717A),
    icon: Color(0xFF3F3F46),
    error: Color(0xFFDC2626),
  ),
  shapes: PaymentSheetShape(borderRadius: 12, borderWidth: 1),
);

Future<void> presentCardPaymentSheet({
  required String publishableKey,
  required String clientSecret,
  required String merchantDisplayName,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  } catch (_) {}
  Stripe.publishableKey = publishableKey;
  Stripe.urlScheme = stripeReturnScheme;
  await Stripe.instance.applySettings();
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: merchantDisplayName,
      returnURL: '$stripeReturnScheme://safepay',
      style: ThemeMode.light,
      appearance: cardPaymentAppearance,
    ),
  );
  await Stripe.instance.presentPaymentSheet();
}
