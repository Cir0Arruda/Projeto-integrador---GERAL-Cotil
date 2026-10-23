// ============================================================================
// ★ PALETA DE CORES E TEMA VISUAL DO RAVEN ASTHA (THEME.DART) ★
// Define a identidade moderna e elegante do aplicativo:
// 1) Verde esmeralda ASTHA (#10B981) como cor de destaque e sucesso :3
// 2) Tipografia limpa, botões com cantos arredondados e cards elegantes (✿◠‿◠)
// 3) Cores semânticas padronizadas (perigo, aviso, informação) (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';

// Cores oficiais do design system do RAVEN ASTHA :3
class AppColors {
  // Fundo cinza bem clarinho e suave pros olhos (*¯︶¯*)
  static const Color background = Color(0xFFF8FAFC);
  // Branco puro para os cartões e superfícies :3
  static const Color surface = Colors.white;
  // Borda sutil para separar seções sem poluir a visão (✿◠‿◠)
  static const Color border = Color(0xFFE2E8F0);
  // Texto principal escuro e com alto contraste :3
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMain = Color(0xFF0F172A);
  // Textos secundários e legendas :3
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  // Verde esmeralda icônico da marca RAVEN ASTHA! ヽ(>∀<☆)ノ
  static const Color brand = Color(0xFF10B981);
  static const Color brandDark = Color(0xFF047857);
  static const Color brandLight = Color(0xFFDDF8EC);
  static const Color brandText = Color(0xFF08774F);
  // Cores semânticas para avisos e erros :3
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
  static const Color purple = Color(0xFF8B5CF6);
}

// Configura o tema completo do Material Design 3 no Flutter (｡•̀ᴗ-)✧
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      surface: AppColors.surface,
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.brand,
        dividerColor: AppColors.border,
      ),
    );
  }
}
