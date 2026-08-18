import 'package:flutter/material.dart';

import '../models/care_models.dart';

// ---------------------------------------------------------------------------
// Design tokens
//
// Layout follows a 4pt grid, radii come from a fixed ramp, and every
// interactive element is at least [pawMinTouch] on its smallest side so it
// clears both the iOS (44pt) and Material (48dp) minimums.
// ---------------------------------------------------------------------------

abstract final class PawSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class PawRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// Smallest allowed hit area for anything tappable.
const double pawMinTouch = 48;

// ---------------------------------------------------------------------------
// Colour
//
// Each accent ships as a pair: the pastel tone is only ever a fill, tint or
// border, while the matching `…Ink` tone carries text and icons. Every ink
// tone clears WCAG AA (4.5:1) against white, cream, lavender and a 16% tint
// of its own accent, so a label never has to guess which surface it landed on.
// ---------------------------------------------------------------------------

// Surfaces
const pawCream = Color(0xFFFFFAF3);
const pawLavender = Color(0xFFF0EAFF);

// Text
const pawInk = Color(0xFF312B43);
const pawMuted = Color(0xFF625C6E);

/// Decorative only — drag handles, dividers. Never text.
const pawMutedSoft = Color(0xFF817A8F);

// Accents (fills) and their readable partners (text and icons)
const pawPurple = Color(0xFF7456D8);
const pawPurpleInk = Color(0xFF613FD3);
const pawPurpleDark = Color(0xFF4F3A98);

const pawRose = Color(0xFFED6F82);
const pawRoseInk = Color(0xFFBE1831);

const pawBlue = Color(0xFF5E9FE6);
const pawBlueInk = Color(0xFF1B62B0);

const pawGreen = Color(0xFF4DAD85);
const pawGreenInk = Color(0xFF306C53);

const pawYellow = Color(0xFFE8AE38);
const pawYellowInk = Color(0xFF845D0F);

const _pawTeal = Color(0xFF48A8C7);
const _pawTealInk = Color(0xFF27697F);
const _pawClay = Color(0xFF8B7768);
const _pawClayInk = Color(0xFF6C5C51);
const _pawTerracotta = Color(0xFFE27B55);
const _pawTerracottaInk = Color(0xFFA5411C);

/// Pastel tone for a category — tints, dots and borders only.
Color categoryColor(CareCategory category) => switch (category) {
  CareCategory.feeding => pawPurple,
  CareCategory.walking => pawBlue,
  CareCategory.medication => pawRose,
  CareCategory.grooming => pawYellow,
  CareCategory.hydration => _pawTeal,
  CareCategory.play => pawGreen,
  CareCategory.training => pawPurpleDark,
  CareCategory.toileting => _pawClay,
  CareCategory.vet => _pawTerracotta,
  CareCategory.other => pawGreen,
};

/// Readable tone for a category — use for any glyph or label.
Color categoryInk(CareCategory category) => switch (category) {
  CareCategory.feeding => pawPurpleInk,
  CareCategory.walking => pawBlueInk,
  CareCategory.medication => pawRoseInk,
  CareCategory.grooming => pawYellowInk,
  CareCategory.hydration => _pawTealInk,
  CareCategory.play => pawGreenInk,
  CareCategory.training => pawPurpleDark,
  CareCategory.toileting => _pawClayInk,
  CareCategory.vet => _pawTerracottaInk,
  CareCategory.other => pawGreenInk,
};

IconData categoryIcon(CareCategory category) => switch (category) {
  CareCategory.feeding => Icons.restaurant_rounded,
  CareCategory.walking => Icons.directions_walk_rounded,
  CareCategory.medication => Icons.medication_rounded,
  CareCategory.grooming => Icons.auto_awesome_rounded,
  CareCategory.hydration => Icons.water_drop_rounded,
  CareCategory.play => Icons.sports_tennis_rounded,
  CareCategory.training => Icons.school_rounded,
  CareCategory.toileting => Icons.cleaning_services_rounded,
  CareCategory.vet => Icons.local_hospital_rounded,
  CareCategory.other => Icons.pets_rounded,
};

/// Bottom inset that keeps scrollable content clear of the navigation bar and,
/// where present, the floating action button. Replaces per-page magic numbers.
double pawListBottomInset(BuildContext context, {bool hasFab = false}) =>
    PawSpace.xxl + (hasFab ? 72 : 0) + MediaQuery.viewPaddingOf(context).bottom;

class PawBackground extends StatelessWidget {
  const PawBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF7), Color(0xFFF9F6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

class PawCard extends StatelessWidget {
  const PawCard({
    required this.child,
    this.padding = const EdgeInsets.all(PawSpace.lg),
    this.color = Colors.white,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PawRadius.xxl),
        border: Border.all(color: pawPurple.withValues(alpha: .08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160E0621),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.detail, super.key});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: textTheme.titleMedium)),
          const SizedBox(width: PawSpace.sm),
          Text(
            detail.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: pawPurpleInk,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({required this.category, this.size = 48, super.key});

  final CareCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: categoryColor(category).withValues(alpha: .14),
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(
        categoryIcon(category),
        color: categoryInk(category),
        size: size * .48,
      ),
    );
  }
}

class PawTag extends StatelessWidget {
  const PawTag({
    required this.label,
    required this.color,
    this.ink,
    this.icon,
    super.key,
  });

  final String label;

  /// Pastel tone used for the tint.
  final Color color;

  /// Readable tone for the label and icon. Defaults to [color] darkened
  /// enough to stay legible on the tint.
  final Color? ink;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = ink ?? _readable(color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PawSpace.sm,
        vertical: PawSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(PawRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: PawSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens [color] until it clears AA against a light surface. Used as a
/// fallback when a caller has no explicit ink token to hand.
Color _readable(Color color) {
  var candidate = color;
  for (var i = 0; i < 24; i++) {
    if (_contrastOnLight(candidate) >= 4.5) return candidate;
    candidate = Color.lerp(candidate, Colors.black, .08)!;
  }
  return candidate;
}

double _contrastOnLight(Color color) =>
    1.05 / (color.computeLuminance() + 0.05);

class PawEmptyState extends StatelessWidget {
  const PawEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.color = pawPurple,
    this.iconColor = pawPurpleInk,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PawCard(
      padding: const EdgeInsets.symmetric(
        horizontal: PawSpace.xxl,
        vertical: PawSpace.xxxl,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: .14),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: PawSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: PawSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: pawMuted),
          ),
        ],
      ),
    );
  }
}

class PawFilledButton extends StatelessWidget {
  const PawFilledButton({
    required this.label,
    required this.onPressed,
    this.color = pawPurple,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, pawMinTouch),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.lg),
        ),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class PawOutlinedButton extends StatelessWidget {
  const PawOutlinedButton({
    required this.label,
    required this.onPressed,
    this.color = pawPurpleInk,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, pawMinTouch),
        side: BorderSide(color: color.withValues(alpha: .42)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.lg),
        ),
      ),
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

String friendlyDate(DateTime value, {bool includeYear = false}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}${includeYear ? ', ${value.year}' : ''}';
}

String friendlyTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
