import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static late SharedPreferences _prefs;

  // Panggil ini sekali di main.dart sebelum runApp
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==========================================
  // ORANG 1 (ATHAYA): INPUT & MAKANAN (AMAN)
  // ==========================================
  
  static double get dailyCalorieTarget => 
      _prefs.getDouble('daily_calorie_target') ?? 2000.0;
  
  static Future<void> setDailyCalorieTarget(double value) async => 
      await _prefs.setDouble('daily_calorie_target', value);

  static String get macroRatioPreference => 
      _prefs.getString('macro_ratio_preference') ?? "50:25:25";
      
  static Future<void> setMacroRatioPreference(String value) async => 
      await _prefs.setString('macro_ratio_preference', value);

  // ==========================================
  // ORANG 2 (ACA): PLANNING & LOGISTIK (AMAN)
  // ==========================================
  
  static String get shoppingDay => 
      _prefs.getString('shopping_day') ?? "Sabtu";
      
  static Future<void> setShoppingDay(String value) async => 
      await _prefs.setString('shopping_day', value);

  static String get defaultDietType => 
      _prefs.getString('default_diet_type') ?? "BALANCED";
      
  static Future<void> setDefaultDietType(String type) async {
    await _prefs.setString('default_diet_type', type);
    if (type == 'HIGH_PROTEIN') setMacroRatioPreference("30:40:30");
    else if (type == 'LOW_CARB') setMacroRatioPreference("25:35:40");
    else if (type == 'KETO') setMacroRatioPreference("5:25:70");
    else setMacroRatioPreference("50:25:25"); // BALANCED
  }

  // ==========================================
  // ORANG 3 (ANNISA): EVALUASI & JURNAL
  // ==========================================
  
  static bool get strictEvaluationMode => 
      _prefs.getBool('strict_evaluation_mode') ?? false;
      
  static Future<void> setStrictEvaluationMode(bool value) async => 
      await _prefs.setBool('strict_evaluation_mode', value);

  static bool get enableSmartInsights => 
      _prefs.getBool('enable_smart_insights') ?? true; 
      
  static Future<void> setEnableSmartInsights(bool value) async => 
      await _prefs.setBool('enable_smart_insights', value);

  // ==========================================
  // FITUR AUTHENTICATION (PINTU MASUK)
  // ==========================================
  
  static bool get isLoggedIn => 
      _prefs.getBool('is_logged_in') ?? false;
      
  static Future<void> setLoggedIn(bool value) async => 
      await _prefs.setBool('is_logged_in', value);

  static String get loggedInUserName => 
      _prefs.getString('logged_in_user_name') ?? "Guest";
      
  static Future<void> setLoggedInUserName(String value) async => 
      await _prefs.setString('logged_in_user_name', value);
}