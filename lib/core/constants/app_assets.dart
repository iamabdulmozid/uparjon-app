/// Central registry of bundled asset paths.
///
/// Only assets listed in `pubspec.yaml` belong here. Full-screen Figma
/// mockup exports under `assets/svg/` are design references and are NOT
/// bundled with the app.
abstract final class AppAssets {
  // Logo
  static const String logo = 'assets/logo/uparjon_logo.svg';
  static const String logoRaster = 'assets/logo/uparjon_logo.png';
  static const String logoWhite = 'assets/logo/splash.svg';

  // Artwork
  static const String splashBackground = 'assets/images/bg_2_1.png';

  // Icons
  static const String iconUser = 'assets/icons/user.svg';
  static const String iconPhone = 'assets/icons/call___phone_.svg';
  static const String iconEmail = 'assets/icons/mail.svg';
  static const String iconEye = 'assets/icons/security___eye.svg';
  static const String iconLock = 'assets/icons/lock.svg';
  static const String iconChevronDown =
      'assets/icons/arrows___alt_arrow_down.svg';
  static const String iconHome = 'assets/icons/essentional_ui___home_.svg';
  static const String iconTrophy = 'assets/icons/essentional_ui___cup_star.svg';
  static const String iconWallet = 'assets/icons/money___wallet_2.svg';
  static const String iconMenu =
      'assets/icons/settings_fine_tuning___widget_.svg';
  static const String iconSuitcase =
      'assets/icons/nature_travel___suitcase_tag.svg';
  static const String iconCart = 'assets/icons/shopping_ecommerce___cart_3.svg';
  static const String iconVideo =
      'assets/icons/video_audio_sound___clapperboard_play.svg';
  static const String iconClipboard = 'assets/icons/notes___clipboard_list.svg';
  static const String iconUpload =
      'assets/icons/arrows_action___upload_minimalistic.svg';

  // Menu rows (extracted from the Figma "Menu" frame)
  static const String menuProfile = 'assets/icons/menu/profile.svg';
  static const String menuSettings = 'assets/icons/menu/settings.svg';
  static const String menuLanguage = 'assets/icons/menu/language.svg';
  static const String menuWithdrawMethod =
      'assets/icons/menu/withdraw_method.svg';
  static const String menuTutorial = 'assets/icons/menu/tutorial.svg';
  static const String menuAbout = 'assets/icons/menu/about.svg';
  static const String menuTerms = 'assets/icons/menu/terms.svg';
  static const String menuSupport = 'assets/icons/menu/support.svg';
  static const String menuFaq = 'assets/icons/menu/faq.svg';
  static const String menuLogout = 'assets/icons/menu/logout.svg';

  // OTP + home artwork
  static const String otpIllustration = 'assets/images/6_digits.png';
  static const String balanceCardTexture = 'assets/images/bg_1.png';
  static const String promoIllustration = 'assets/images/image_24.png';
  static const String moneyBag = 'assets/images/money_bag.svg';

  // Onboarding illustrations (exported at 3x: 1086x1448)
  static const String onboardingEarn = 'assets/images/image_26.png';
  static const String onboardingHire = 'assets/images/image_27.png';
  static const String onboardingGrow = 'assets/images/image_28.png';
}
