import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'compat_logic.dart';
import '../core/usage.dart';

/// Opens the compatibility test from anywhere in the app.
void openCompatibility(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CompatibilityScreen()));
}

// ---------------------------------------------------------------------------
// Step 1: pick two genotypes

class CompatibilityScreen extends StatefulWidget {
  const CompatibilityScreen({super.key});
  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  String? _you;
  String? _partner;

  @override
  void initState() {
    super.initState();
    final own = context.read<AuthState>().user?['genotype'] as String?;
    if (own != null && kCompatGenotypes.contains(own)) _you = own;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _you != null && _partner != null;
    return AuthScaffold(
      title: 'Test compatibility',
      subtitle: 'Pick two genotypes to see the chances for their children.',
      backTo: '/welcome',
      onBack: () => Navigator.of(context).pop(),
      children: [
        _Picker(
          label: 'Your genotype',
          value: _you,
          onChanged: (v) => setState(() => _you = v),
        ),
        const SizedBox(height: 22),
        _Picker(
          label: "Partner's genotype",
          value: _partner,
          onChanged: (v) => setState(() => _partner = v),
        ),
        const SizedBox(height: 14),
        Text(
          'Genotypes you enter here are not verified.',
          style: AppText.body(14, FontWeight.w500, AppColors.muted),
        ),
        const SizedBox(height: 22),
        Opacity(
          opacity: ready ? 1 : 0.45,
          child: PrimaryButton(
            'See result',
            onPressed: () {
              if (!ready) return;
              Usage.log(context, 'compat_check');
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompatibilityResultScreen(
                    result: computeCompat(_you!, _partner!),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppText.body(
          14,
          FontWeight.w700,
          AppColors.muted,
        ).copyWith(letterSpacing: 1.2),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final g in kCompatGenotypes)
            GestureDetector(
              onTap: () => onChanged(g),
              child: Container(
                width: 82,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: g == value ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: g == value ? AppColors.gold : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  g,
                  style: AppText.body(
                    18,
                    FontWeight.w700,
                    g == value ? AppColors.onGold : AppColors.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Step 2: the result

class CompatibilityResultScreen extends StatelessWidget {
  const CompatibilityResultScreen({super.key, required this.result, this.note});
  final CompatResult result;
  final String? note;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: '${result.parent1} × ${result.parent2}',
    subtitle: 'What could happen in each pregnancy',
    backTo: '/welcome',
    onBack: () => Navigator.of(context).pop(),
    children: [
      if (note != null) ...[
        Text(note!, style: AppText.body(14, FontWeight.w500, AppColors.muted)),
        const SizedBox(height: 14),
      ],
      _RiskCard(result),
      const SizedBox(height: 16),
      _OutcomesCard(result),
      const SizedBox(height: 16),
      _GridCard(result),
      const SizedBox(height: 16),
      Text(
        'This is for education, not medical advice. The chances are the same for every pregnancy, '
        'whatever happened in earlier ones. A genetic counsellor or doctor can explain your options.',
        style: AppText.body(14, FontWeight.w500, AppColors.muted),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        'Try another pair',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

(Color bg, Color fg, String label) _riskStyle(Risk r) => switch (r) {
  Risk.none => (AppColors.greenTint, AppColors.green, 'No risk'),
  Risk.elevated => (AppColors.amberTint, AppColors.gold, 'Elevated risk'),
  Risk.high => (AppColors.redTint, AppColors.red, 'High risk'),
  Risk.veryHigh => (AppColors.redTint, AppColors.red, 'Very high risk'),
};

Color _genoColor(String g) => switch (g) {
  'AA' => AppColors.green,
  'SS' || 'SC' => AppColors.red,
  _ => AppColors.gold, // carriers and CC
};

class _RiskCard extends StatelessWidget {
  const _RiskCard(this.r);
  final CompatResult r;

  String get _headline => r.scdPercent == 0
      ? 'No chance of sickle cell disease'
      : (r.scdPercent == 100
            ? 'Every child would have sickle cell disease'
            : '${r.scdPercent}% chance of sickle cell disease');

  String get _body {
    switch (r.risk) {
      case Risk.none:
        return r.hasCarrier
            ? 'No child would have SS or SC. Some children may be carriers (AS or AC). Carriers are not ill, '
                  'but can pass the gene on.'
            : 'No child would have SS or SC, and none would be carriers.';
      case Risk.elevated:
        return 'About 1 in 4 children would have sickle cell disease. Genetic counselling can help you understand '
            'your options.';
      case Risk.high:
        return 'About 1 in 2 children would have sickle cell disease. Speaking to a genetic counsellor before '
            'deciding is strongly advised.';
      case Risk.veryHigh:
        return r.scdPercent == 100
            ? 'All children would have SS or SC. Speaking to a genetic counsellor before deciding is strongly advised.'
            : 'About 3 in 4 children would have sickle cell disease. Speaking to a genetic counsellor before '
                  'deciding is strongly advised.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _riskStyle(r.risk);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withAlpha(120), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.body(
              13,
              FontWeight.w800,
              fg,
            ).copyWith(letterSpacing: 1.3),
          ),
          const SizedBox(height: 8),
          Text(_headline, style: AppText.heading(26)),
          const SizedBox(height: 8),
          Text(_body, style: AppText.body(16, FontWeight.w500)),
        ],
      ),
    );
  }
}

class _OutcomesCard extends StatelessWidget {
  const _OutcomesCard(this.r);
  final CompatResult r;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Possible children', style: AppText.body(19, FontWeight.w700)),
        const SizedBox(height: 14),
        for (final o in r.outcomes) ...[
          Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _genoColor(o.genotype).withAlpha(45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  o.genotype,
                  style: AppText.body(
                    15,
                    FontWeight.w800,
                    _genoColor(o.genotype),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  genotypeLabel(o.genotype),
                  style: AppText.body(16, FontWeight.w600),
                ),
              ),
              Text('${o.percent}%', style: AppText.body(18, FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: o.percent / 100,
              minHeight: 10,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(_genoColor(o.genotype)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

class _GridCard extends StatelessWidget {
  const _GridCard(this.r);
  final CompatResult r;

  Widget _head(String text) => Expanded(
    child: Container(
      height: 44,
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppText.body(17, FontWeight.w800, AppColors.muted),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cols = r.parent2.split('');
    final rows = r.parent1.split('');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it is worked out',
            style: AppText.body(19, FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Each parent passes on one of their two genes. Across the top are the genes from ${r.parent2}, '
            'down the side the genes from ${r.parent1}. Each box is a 25% chance.',
            style: AppText.body(14, FontWeight.w500, AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 44),
              for (final c in cols) _head(c),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 56,
                  child: Center(
                    child: Text(
                      rows[i],
                      style: AppText.body(17, FontWeight.w800, AppColors.muted),
                    ),
                  ),
                ),
                for (var j = 0; j < cols.length; j++)
                  Expanded(
                    child: Container(
                      height: 52,
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _genoColor(r.grid[i][j]).withAlpha(45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        r.grid[i][j],
                        style: AppText.body(
                          18,
                          FontWeight.w800,
                          _genoColor(r.grid[i][j]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
