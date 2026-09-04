import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/location_municipality_service.dart';

class MunicipalityState {
  static final MunicipalityState _instance = MunicipalityState._internal();
  factory MunicipalityState() => _instance;
  MunicipalityState._internal();

  ValueNotifier<String> selectedMunicipality = ValueNotifier<String>('Bambang');
  ValueNotifier<String> language = ValueNotifier<String>('English');
  ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  // When true, the app auto-selects the municipality nearest to the user's
  // current location on startup (opt-in). When false, the user picks manually.
  ValueNotifier<bool> useLocationMunicipality = ValueNotifier<bool>(false);

  Map<String, dynamic> get activeTheme =>
      AppConstants.municipalityThemes[selectedMunicipality.value] ??
      AppConstants.municipalityThemes['Generic']!;

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    selectedMunicipality.value = prefs.getString('selected_municipality') ?? 'Bambang';
    final lang = prefs.getString('language') ?? 'English';
    language.value = lang;
    // FIX 7: Keep the AppStrings helper in sync with persisted language
    oneVizcayaStateLang = lang;
    isDarkMode.value = prefs.getBool('dark_mode') ?? false;
    useLocationMunicipality.value =
        prefs.getBool('use_location_municipality') ?? false;
  }

  Future<void> setUseLocationMunicipality(bool value) async {
    useLocationMunicipality.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_location_municipality', value);
    // Turning it on: immediately snap to the user's location.
    if (value) await autoSelectFromLocation();
  }

  /// If the location toggle is on, detect the nearest municipality and select
  /// it. No-op when the toggle is off or location is unavailable — the manual
  /// selection is preserved in that case.
  Future<void> autoSelectFromLocation() async {
    if (!useLocationMunicipality.value) return;
    final muni = await LocationMunicipalityService.detectNearest();
    if (muni != null &&
        AppConstants.municipalities.contains(muni) &&
        muni != selectedMunicipality.value) {
      await setMunicipality(muni);
    }
  }

  Future<void> setMunicipality(String municipality) async {
    selectedMunicipality.value = municipality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_municipality', municipality);
  }

  Future<void> setLanguage(String lang) async {
    language.value = lang;
    // FIX 7: Keep the AppStrings helper in sync whenever the language changes
    oneVizcayaStateLang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }
}

final oneVizcayaState = MunicipalityState();
