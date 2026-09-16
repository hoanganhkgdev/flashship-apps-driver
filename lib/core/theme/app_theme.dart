import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFFFF6035);
  static const primaryDark = Color(0xFFD83A05);
  static const primarySoft = Color(0xFFFFEAE3);
  static const primaryGradientStart = Color(0xFFCC5A08);
  static const primaryGradientMiddle = Color(0xFFE8720C);
  static const primaryGradientEnd = Color(0xFFF59E30);

  static const secondary = Color(0xFF008F92);
  static const secondarySoft = Color(0xFFE3F5F4);

  static const background = Color(0xFFF2F3F5);
  static const surface = Color(0xFFFFFEFD);
  static const surfaceAlt = Color(0xFFF5F5F5);

  static const textPrimary = Color(0xFF1B1411);
  static const textSecondary = Color(0xFF6A605C);
  static const textTertiary = Color(0xFFA99F9A);
  static const divider = Color(0xFFE5DDD9);

  static const success = Color(0xFF229650);
  static const successSoft = Color(0xFFE7F8F1);
  static const danger = Color(0xFFD52E36);
  static const dangerSoft = Color(0xFFFFE5E2);
  static const warning = Color(0xFFBE7900);
  static const warningSoft = Color(0xFFFFF1CC);
  static const warningStrong = Color(0xFFE65100);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFEFF5FF);

  // Xám trung tính dùng cho nhãn phụ ("bỏ qua", "để sau"...) và icon mờ.
  static const textMuted = Color(0xFF9E9E9E);
  static const slate = Color(0xFF6B7280);
  static const iconMuted = Color(0xFFD0D0D5);

  // Cam nhấn cho icon danh mục/dải giờ ca (không mang nghĩa trạng thái).
  static const amber = Color(0xFFF59E0B);

  // Alias chuyển tiếp; code mới dùng secondary/secondarySoft.
  static const accent2 = secondary;
  static const accent2Soft = secondarySoft;
}

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
  static const xl5 = 48.0;
}

abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const card = lg;
  static const full = 999.0;
}

abstract final class AppSize {
  static const minTouchTarget = 48.0;
  static const buttonHeight = 50.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppFontSize {
  static const xs = 10.0;
  static const sm = 12.0;
  static const base = 14.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 28.0;
  static const xl4 = 32.0;
  static const xl5 = 36.0;
  static const xl6 = 40.0;
  static const xl7 = 48.0;
}

abstract final class AppTextStyles {
  static const screenTitle = TextStyle(
      fontSize: AppFontSize.xl, height: 1.2, fontWeight: FontWeight.w600);
  static const sectionTitle = TextStyle(
      fontSize: AppFontSize.md, height: 1.25, fontWeight: FontWeight.w800);
  static const body = TextStyle(
      fontSize: AppFontSize.base, height: 1.4, fontWeight: FontWeight.w500);
  static const bodyStrong = TextStyle(
      fontSize: AppFontSize.base, height: 1.35, fontWeight: FontWeight.w700);
  static const label = TextStyle(
      fontSize: AppFontSize.sm, height: 1.3, fontWeight: FontWeight.w600);
  static const caption = TextStyle(
      fontSize: AppFontSize.xs, height: 1.3, fontWeight: FontWeight.w600);
  static const metric = TextStyle(
      fontSize: AppFontSize.xl,
      height: 1.1,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.2);
  static const metricLarge = TextStyle(
      fontSize: AppFontSize.xl4,
      height: 1.05,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6);
}

abstract final class AppShadows {
  static const soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F1B1411),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A1B1411),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(colorScheme: colorScheme).textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(
          color: AppColors.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        toolbarHeight: 60,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x261B1411),
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: const Color(0x1A1B1411),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
          minimumSize: const Size(64, AppSize.buttonHeight),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
              Size(AppSize.minTouchTarget, AppSize.minTouchTarget)),
          iconSize: const WidgetStatePropertyAll(AppSize.iconLg),
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          )),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            )),
        labelTextStyle:
            WidgetStateProperty.resolveWith((states) => GoogleFonts.inter(
                  fontSize: AppFontSize.sm,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.textSecondary,
                )),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.divider;
          return states.contains(WidgetState.selected)
              ? AppColors.success
              : AppColors.textTertiary;
        }),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
