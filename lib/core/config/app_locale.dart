import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

class AppLocale {
  const AppLocale._();

  static const String primaryFormattingLocale = 'id_ID';
  static const String fallbackFormattingLocale = 'en_US';

  static const Locale primaryLocale = Locale('id', 'ID');
  static const Locale fallbackLocale = Locale('en', 'US');
  static const List<Locale> supportedLocales = [
    primaryLocale,
    fallbackLocale,
  ];

  static String _formattingLocale = primaryFormattingLocale;
  static Locale _materialLocale = primaryLocale;

  static String get formattingLocale => _formattingLocale;
  static Locale get materialLocale => _materialLocale;

  static Future<void> initialize() async {
    try {
      await initializeDateFormatting(primaryFormattingLocale, null);
      _formattingLocale = primaryFormattingLocale;
      _materialLocale = primaryLocale;
    } catch (_) {
      _formattingLocale = fallbackFormattingLocale;
      _materialLocale = fallbackLocale;

      try {
        await initializeDateFormatting(fallbackFormattingLocale, null);
      } catch (_) {}
    }
  }
}
