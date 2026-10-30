const kCompatGenotypes = ['AA', 'AS', 'AC', 'SS', 'SC'];

const _order = ['AA', 'AS', 'AC', 'SS', 'SC', 'CC'];

enum Risk { none, elevated, high, veryHigh }

class ChildOutcome {
  const ChildOutcome(this.genotype, this.percent);
  final String genotype;
  final int percent;
}

class CompatResult {
  const CompatResult({
    required this.parent1,
    required this.parent2,
    required this.outcomes,
    required this.grid,
  });

  final String parent1;
  final String parent2;
  final List<ChildOutcome> outcomes;

  final List<List<String>> grid;

  /// Chance of a child with sickle cell disease: SS or SC.
  int get scdPercent => outcomes
      .where((o) => o.genotype == 'SS' || o.genotype == 'SC')
      .fold(0, (s, o) => s + o.percent);

  bool get hasCarrier =>
      outcomes.any((o) => o.genotype == 'AS' || o.genotype == 'AC');

  Risk get risk {
    final p = scdPercent;
    if (p == 0) return Risk.none;
    if (p <= 25) return Risk.elevated;
    if (p <= 50) return Risk.high;
    return Risk.veryHigh;
  }
}

/// Puts a pair of genes in the standard order: "SA" -> "AS", "CS" -> "SC".
String _canonical(String a, String b) {
  final genes = [a, b]..sort();
  final g = genes.join();
  return g == 'CS' ? 'SC' : g;
}

CompatResult computeCompat(String parent1, String parent2) {
  assert(parent1.length == 2 && parent2.length == 2);
  final g1 = parent1.split('');
  final g2 = parent2.split('');

  final grid = [
    for (final a in g1) [for (final b in g2) _canonical(a, b)],
  ];

  final counts = <String, int>{};
  for (final row in grid) {
    for (final g in row) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }

  final outcomes = [
    for (final g in _order)
      if (counts.containsKey(g)) ChildOutcome(g, counts[g]! * 25),
  ];
  return CompatResult(
    parent1: parent1,
    parent2: parent2,
    outcomes: outcomes,
    grid: grid,
  );
}

/// Plain-language name for a genotype.
String genotypeLabel(String g) => switch (g) {
  'AA' => 'Normal haemoglobin',
  'AS' => 'Sickle cell trait (carrier)',
  'AC' => 'Haemoglobin C trait (carrier)',
  'SS' => 'Sickle cell disease (SS)',
  'SC' => 'Sickle cell disease (SC)',
  'CC' => 'Haemoglobin C disease (rare, usually mild)',
  _ => g,
};
