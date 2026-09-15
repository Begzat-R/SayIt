class Scenario {
  final String id;
  final String title;
  final String context;
  final String iconName;
  final String? simulatedPrompt;
  final String category;

  const Scenario({
    required this.id,
    required this.title,
    required this.context,
    required this.iconName,
    required this.category,
    this.simulatedPrompt,
  });
}
