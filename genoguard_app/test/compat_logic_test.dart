import 'package:flutter_test/flutter_test.dart';
import 'package:genoguard_app/compat/compat_logic.dart';

int pct(CompatResult r, String g) =>
    r.outcomes.where((o) => o.genotype == g).fold(0, (s, o) => s + o.percent);

void main() {
  group('Punnett square outcomes', () {
    test('AA x AA gives only AA children and no risk', () {
      final r = computeCompat('AA', 'AA');
      expect(pct(r, 'AA'), 100);
      expect(r.scdPercent, 0);
      expect(r.risk, Risk.none);
      expect(r.hasCarrier, false);
    });

    test(
      'AS x AS: 25% AA, 50% AS, 25% SS, so a 25% chance of sickle cell disease',
      () {
        final r = computeCompat('AS', 'AS');
        expect(pct(r, 'AA'), 25);
        expect(pct(r, 'AS'), 50);
        expect(pct(r, 'SS'), 25);
        expect(r.scdPercent, 25);
        expect(r.risk, Risk.elevated);
        expect(r.hasCarrier, true);
      },
    );

    test('AS x AA: children can be carriers but never have the disease', () {
      final r = computeCompat('AS', 'AA');
      expect(pct(r, 'AA'), 50);
      expect(pct(r, 'AS'), 50);
      expect(r.scdPercent, 0);
      expect(r.risk, Risk.none);
      expect(r.hasCarrier, true);
    });

    test('AS x SS: half the children have SS', () {
      final r = computeCompat('AS', 'SS');
      expect(pct(r, 'AS'), 50);
      expect(pct(r, 'SS'), 50);
      expect(r.scdPercent, 50);
      expect(r.risk, Risk.high);
    });

    test('SS x SS: every child has SS', () {
      final r = computeCompat('SS', 'SS');
      expect(pct(r, 'SS'), 100);
      expect(r.scdPercent, 100);
      expect(r.risk, Risk.veryHigh);
    });

    test('SC x SC counts SS and SC as sickle cell disease and shows CC', () {
      final r = computeCompat('SC', 'SC');
      expect(pct(r, 'SS'), 25);
      expect(pct(r, 'SC'), 50);
      expect(pct(r, 'CC'), 25);
      expect(r.scdPercent, 75);
      expect(r.risk, Risk.veryHigh);
    });

    test(
      'AC x AS puts the pair of genes in standard order (CS becomes SC)',
      () {
        final r = computeCompat('AC', 'AS');
        expect(pct(r, 'AA'), 25);
        expect(pct(r, 'AS'), 25);
        expect(pct(r, 'AC'), 25);
        expect(pct(r, 'SC'), 25);
        expect(r.scdPercent, 25);
      },
    );

    test('AC x AC: carriers only, no sickle cell disease', () {
      final r = computeCompat('AC', 'AC');
      expect(pct(r, 'AC'), 50);
      expect(pct(r, 'CC'), 25);
      expect(r.scdPercent, 0);
      expect(r.hasCarrier, true);
    });
  });

  group('Properties that must hold for every pair the app offers', () {
    test('outcomes always add up to 100%', () {
      for (final a in kCompatGenotypes) {
        for (final b in kCompatGenotypes) {
          final total = computeCompat(
            a,
            b,
          ).outcomes.fold(0, (s, o) => s + o.percent);
          expect(total, 100, reason: '$a x $b');
        }
      }
    });

    test('the order of the parents does not change the result', () {
      for (final a in kCompatGenotypes) {
        for (final b in kCompatGenotypes) {
          final x = computeCompat(a, b);
          final y = computeCompat(b, a);
          for (final g in ['AA', 'AS', 'AC', 'SS', 'SC', 'CC']) {
            expect(pct(x, g), pct(y, g), reason: '$a x $b vs $b x $a, $g');
          }
        }
      }
    });

    test('the grid is 2x2', () {
      final r = computeCompat('AS', 'AC');
      expect(r.grid.length, 2);
      expect(r.grid.every((row) => row.length == 2), true);
    });
  });

  group('Labels', () {
    test('plain-language names', () {
      expect(genotypeLabel('AA'), 'Normal haemoglobin');
      expect(genotypeLabel('AS'), 'Sickle cell trait (carrier)');
      expect(genotypeLabel('SS'), 'Sickle cell disease (SS)');
    });

    test('an unknown genotype falls back to its own text', () {
      expect(genotypeLabel('XX'), 'XX');
    });
  });
}
