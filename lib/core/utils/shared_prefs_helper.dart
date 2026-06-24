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

  static String get lastShoppingNotificationDate => 
      _prefs.getString('last_shopping_notification_date') ?? "";
      
  static Future<void> setLastShoppingNotificationDate(String value) async => 
      await _prefs.setString('last_shopping_notification_date', value);

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

  static int get loggedInUserId => 
      _prefs.getInt('logged_in_user_id') ?? 1; 
      
  static Future<void> setLoggedInUserId(int id) async => 
      await _prefs.setInt('logged_in_user_id', id);

  static Future<void> clearAuthData() async {
    await _prefs.setBool('is_logged_in', false);
    await _prefs.remove('logged_in_user_name');
    await _prefs.remove('logged_in_user_id');
  }

  // ==========================================
  // ---> NEW: MEMORI API MAKANAN HARIAN <---
  // ==========================================
  
  static String get lastApiDate => 
      _prefs.getString('last_api_date') ?? "";
      
  static Future<void> setLastApiDate(String date) async => 
      await _prefs.setString('last_api_date', date);

  static String get cachedMealName => 
      _prefs.getString('cached_meal_name') ?? "Mencari inspirasi menu...";
      
  static Future<void> setCachedMealName(String name) async => 
      await _prefs.setString('cached_meal_name', name);

  static String get cachedMealCategory => 
      _prefs.getString('cached_meal_category') ?? "";
      
  static Future<void> setCachedMealCategory(String category) async => 
      await _prefs.setString('cached_meal_category', category);

  // ---> TAMBAHAN BARU: WADAH UNTUK FOTO MAKANAN <---
  static String get cachedMealThumb => 
      _prefs.getString('cached_meal_thumb') ?? "";
      
  static Future<void> setCachedMealThumb(String url) async => 
      await _prefs.setString('cached_meal_thumb', url);
}