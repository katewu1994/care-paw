import 'package:flutter/material.dart';

import '../widgets/paw_ui.dart';

class ProPage extends StatelessWidget {
  const ProPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PawSpace.lg,
        PawSpace.sm,
        PawSpace.lg,
        PawSpace.xxl,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(PawSpace.xxl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [pawPurpleDark, pawPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(PawRadius.xxl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x384F3A98),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0x33FFFFFF),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: PawSpace.md),
              const Text(
                'More calm, more care.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: PawSpace.sm),
              const Text(
                'copaw Pro gives every caregiver a clearer shared routine.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xEFFFFFFF), height: 1.35),
              ),
              const SizedBox(height: PawSpace.lg),
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Purchases are not connected in this offline Flutter build yet.',
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: pawPurpleDark,
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Coming soon'),
              ),
            ],
          ),
        ),
        const SizedBox(height: PawSpace.xxl),
        const SectionHeader(
          title: 'Made for shared care',
          detail: 'Pro preview',
        ),
        const SizedBox(height: PawSpace.md),
        const _Feature(
          icon: Icons.notifications_active_rounded,
          color: pawRoseInk,
          title: 'Smart reminders',
          detail: 'Nudge the right person at the right time.',
        ),
        const SizedBox(height: PawSpace.md),
        const _Feature(
          icon: Icons.insights_rounded,
          color: pawBlueInk,
          title: 'Care insights',
          detail: 'Spot routines that keep your pet happiest.',
        ),
        const SizedBox(height: PawSpace.md),
        const _Feature(
          icon: Icons.groups_rounded,
          color: pawGreenInk,
          title: 'More caregivers',
          detail: 'Keep the whole pet village in the loop.',
        ),
        const SizedBox(height: PawSpace.xxl),
        const _PriceCard(
          title: 'Monthly',
          price: '¥480',
          detail: 'Cancel anytime',
        ),
        const SizedBox(height: PawSpace.md),
        const _PriceCard(
          title: 'Yearly',
          price: '¥3,800',
          detail: 'Save 34% · best value',
          highlighted: true,
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => PawCard(
    padding: const EdgeInsets.all(PawSpace.md),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .14),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: PawSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: pawInk,
                ),
              ),
              const SizedBox(height: PawSpace.xxs),
              Text(
                detail,
                style: const TextStyle(color: pawMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.title,
    required this.price,
    required this.detail,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String detail;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PawSpace.lg),
    decoration: BoxDecoration(
      color: highlighted ? pawLavender : Colors.white,
      borderRadius: BorderRadius.circular(PawRadius.xl),
      border: Border.all(
        color: highlighted ? pawPurple : pawPurple.withValues(alpha: .1),
        width: highlighted ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: pawInk,
                ),
              ),
              const SizedBox(height: PawSpace.xxs),
              Text(
                detail,
                style: TextStyle(
                  color: highlighted ? pawPurpleDark : pawMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: pawInk,
          ),
        ),
        const Text(' / year', style: TextStyle(color: pawMuted, fontSize: 12)),
      ],
    ),
  );
}
