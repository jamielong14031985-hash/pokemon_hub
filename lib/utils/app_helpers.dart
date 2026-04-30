import 'dart:math' as math;

String friendPokedexLabel(String friendName) {
  final trimmed = friendName.trim();
  if (trimmed.isEmpty) return 'Friend Pokédex';
  return trimmed.toLowerCase().endsWith('s') ? "$trimmed' Pokédex" : "$trimmed's Pokédex";
}

String generateLocalDocumentId() {
  final random = math.Random();
  return '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1 << 32)}';
}
