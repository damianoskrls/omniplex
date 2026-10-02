import '../services/translation_service.dart';

/// Greek copy stays as written. In English it is translated, with AI when
/// the phrase is not already in the app's dictionary.
String tr(String text) => TranslationService.instance.lookup(text);
