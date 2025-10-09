import 'package:flutter/material.dart';

/// A compact, branded alert card that reflects AI state
/// (loading / success / warning / error) and exposes an action button.
///
/// Defaults to an informative state so you can drop it into UIs without
/// wiring everything on day one. Brand: MyTradeMate.
class AIAlertCard extends StatelessWidget {
  /// Called when the primary button is pressed. If null, the button is disabled.
  final VoidCallback? onPressed;

  /// Optional title (defaults based on [variant] / [isLoading] / [errorText]).
  final String? title;

  /// Optional subtitle/body (defaults based on state).
  final String? subtitle;

  /// Button label (defaults to state-appropriate text).
  final String? buttonText;

  /// Show a progress indicator and disable interaction when true.
  final bool isLoading;

  /// When non-null, the card switches to an error variant and shows the text.
  final String? errorText;

  /// If you already computed how many recommendations are ready, pass it here.
  /// When provided and > 0, the card uses a success variant automatically.
  final int? recommendationCount;

  /// Visual tone override (info/success/warning/error). If null, we derive it
  /// from [isLoading], [errorText], and [recommendationCount].
  final AIAlertVariant? variant;

  const AIAlertCard({
    super.key,
    this.onPressed,
    this.title,
    this.subtitle,
    this.buttonText,
    this.isLoading = false,
    this.errorText,
    this.recommendationCount,
    this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final derivedVariant = _deriveVariant();
    final palette = _paletteFor(derivedVariant);

    final resolvedTitle = title ?? _defaultTitle(derivedVariant);
    final resolvedSubtitle = subtitle ?? _defaultSubtitle(derivedVariant);
    final resolvedButton = buttonText ?? _defaultButton(derivedVariant);

    final disabled = isLoading ||
        onPressed == null ||
        derivedVariant == AIAlertVariant.error;

    return Card(
      color: palette.background,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LeadingIcon(
                  variant: derivedVariant,
                  palette: palette,
                  isLoading: isLoading),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      errorText ??
                          _appendRecCount(
                              resolvedSubtitle, recommendationCount),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.subtitle,
                        fontSize: 13.5,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: disabled ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      disabled ? palette.buttonDisabled : palette.button,
                  foregroundColor: palette.buttonText,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  resolvedButton,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AIAlertVariant _deriveVariant() {
    if (errorText != null && errorText!.trim().isNotEmpty) {
      return AIAlertVariant.error;
    }
    if (isLoading) return AIAlertVariant.info;
    if ((recommendationCount ?? 0) > 0) return AIAlertVariant.success;
    return variant ?? AIAlertVariant.info;
  }

  static String _appendRecCount(String base, int? count) {
    if (count == null || count <= 0) return base;
    return '$base  •  $count recommendation${count == 1 ? '' : 's'} ready';
  }

  String _defaultTitle(AIAlertVariant v) {
    switch (v) {
      case AIAlertVariant.info:
        return 'MyTradeMate AI is analyzing…';
      case AIAlertVariant.success:
        return 'AI opportunity detected';
      case AIAlertVariant.warning:
        return 'AI needs your review';
      case AIAlertVariant.error:
        return 'AI unavailable';
    }
  }

  String _defaultSubtitle(AIAlertVariant v) {
    switch (v) {
      case AIAlertVariant.info:
        return 'Crunching signals and volatility to find entries.';
      case AIAlertVariant.success:
        return 'We found a potential setup. Review before placing an order.';
      case AIAlertVariant.warning:
        return 'Inputs look unusual. Double‑check your symbol and timeframe.';
      case AIAlertVariant.error:
        return 'Model load or prediction failed. Trading & prices still work.';
    }
  }

  String _defaultButton(AIAlertVariant v) {
    switch (v) {
      case AIAlertVariant.info:
        return 'Working…';
      case AIAlertVariant.success:
        return 'View recommendations';
      case AIAlertVariant.warning:
        return 'Review';
      case AIAlertVariant.error:
        return 'Retry';
    }
  }

  _Palette _paletteFor(AIAlertVariant v) {
    switch (v) {
      case AIAlertVariant.info:
        return const _Palette(
          background: Color(0xFF1B1530),
          title: Colors.white,
          subtitle: Colors.white70,
          icon: Colors.cyanAccent,
          button: Color(0xFF2CDA9D),
          buttonDisabled: Color(0xFF3A3650),
          buttonText: Colors.white,
        );
      case AIAlertVariant.success:
        return const _Palette(
          background: Color(0xFF0E2A1E),
          title: Color(0xFFE8FFF3),
          subtitle: Color(0xFFBFE9D5),
          icon: Color(0xFF2CDA9D),
          button: Color(0xFF2CDA9D),
          buttonDisabled: Color(0xFF214536),
          buttonText: Colors.white,
        );
      case AIAlertVariant.warning:
        return const _Palette(
          background: Color(0xFF2A240E),
          title: Color(0xFFFFF7E6),
          subtitle: Color(0xFFEAD9A1),
          icon: Color(0xFFFFC107),
          button: Color(0xFFFFC107),
          buttonDisabled: Color(0xFF4A442E),
          buttonText: Colors.black,
        );
      case AIAlertVariant.error:
        return const _Palette(
          background: Color(0xFF2A1010),
          title: Color(0xFFFFE8E8),
          subtitle: Color(0xFFF5BDBD),
          icon: Color(0xFFE57373),
          button: Color(0xFFE57373),
          buttonDisabled: Color(0xFF4A2B2B),
          buttonText: Colors.white,
        );
    }
  }
}

class _LeadingIcon extends StatelessWidget {
  final AIAlertVariant variant;
  final _Palette palette;
  final bool isLoading;
  const _LeadingIcon(
      {required this.variant, required this.palette, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final icon = switch (variant) {
      AIAlertVariant.info => Icons.psychology,
      AIAlertVariant.success => Icons.trending_up,
      AIAlertVariant.warning => Icons.warning_amber_rounded,
      AIAlertVariant.error => Icons.error_outline,
    };

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: palette.icon, size: 28),
          if (isLoading)
            const Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum AIAlertVariant { info, success, warning, error }

class _Palette {
  final Color background;
  final Color title;
  final Color subtitle;
  final Color icon;
  final Color button;
  final Color buttonDisabled;
  final Color buttonText;
  const _Palette({
    required this.background,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.button,
    required this.buttonDisabled,
    required this.buttonText,
  });
}



