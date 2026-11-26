import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  // Cam mơ thống nhất; giữ chữ và icon đậm khi dùng ngoài trời.
  static const primary = Color(0xFFFF9A5C);
  static const primaryDark = Color(0xFFAD4E20);
  static const primarySoft = Color(0xFFFFF0E6);
  static const primaryGradientStart = primary;
  static const primaryGradientMiddle = primary;
  static const primaryGradientEnd = primary;

  static const secondary = Color(0xFF00B3B5);
  static const secondarySoft = Color(0xFFD1F3F2);

  static const background = Color(0xFFF3F4F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F2F3);

  static const textPrimary = Color(0xFF1C1410);
  static const textSecondary = Color(0xFF41464D);
  static const textTertiary = Color(0xFF565D65);
  static const divider = Color(0xFFBCC3CA);

  static const success = Color(0xFF16733C);
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
  static const amber = primary;

  // Alias chuyển tiếp; code mới dùng secondary/secondarySoft.
  static const accent2 = secondary;
  static const accent2Soft = secondarySoft;
}

abstract final class AppBrand {
  static const ink = Color(0xFF472000);
  // Giữ chung một nguồn màu cho các thành phần đang dùng gradient.
  static const gradient = LinearGradient(
    colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
  static const card = md;
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
      fontSize: AppFontSize.md, height: 1.25, fontWeight: FontWeight.w700);
  static const body = TextStyle(
      fontSize: AppFontSize.base, height: 1.4, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(
      fontSize: AppFontSize.base, height: 1.35, fontWeight: FontWeight.w600);
  static const label = TextStyle(
      fontSize: AppFontSize.sm, height: 1.3, fontWeight: FontWeight.w500);
  static const caption =
      TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500);
  static const metric = TextStyle(
      fontSize: AppFontSize.xl,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2);
  static const metricLarge = TextStyle(
      fontSize: AppFontSize.xl4,
      height: 1.05,
      fontWeight: FontWeight.w700,
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
      primary: AppColors.primary,
      onPrimary: AppBrand.ink,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppBrand.ink,
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
        elevation: 0,
        scrolledUnderElevation: 0.5,
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
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppBrand.ink,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          minimumSize: const Size(64, AppSize.buttonHeight),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primaryDark, width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
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
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.25),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.25),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
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
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
