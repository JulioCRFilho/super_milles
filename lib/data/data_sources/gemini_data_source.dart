import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/entities/generated_loot_data.dart';
import '../../domain/entities/equipment_slot.dart';

class GeminiDataSource {
  final String? apiKey;
  late final GenerativeModel? _model;

  GeminiDataSource({this.apiKey}) {
    if (apiKey != null && apiKey!.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey!,
      );
    } else {
      _model = null;
    }
  }

  Future<GeneratedLootData> generateLoot(int level) async {
    final model = _model;
    if (model == null) {
      // Fallback if no API key
      return _generateFallbackLoot(level);
    }

    try {
      final prompt = '''
        Gere um item de recompensa por vencer um CHEFE nível $level em um RPG de Fantasia.
        Pode ser Bota (Boots), Acessório, Capacete, Armadura, Calça ou Luva.
        Faça parecer Épico e Poderoso. Responda em Português.
        O aumento de status deve ser entre 5 e 20.
        
        Responda APENAS em formato JSON:
        {
          "name": "Nome do item",
          "type": "BOOTS|ACCESSORY|HELMET|ARMOR|PANTS|GLOVES",
          "statBoost": número entre 5 e 20,
          "description": "Descrição do item"
        }
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return _generateFallbackLoot(level);
      }

      // Simple JSON parsing (in production, use proper JSON parsing)
      return _parseLootFromText(text, level);
    } catch (e) {
      return _generateFallbackLoot(level);
    }
  }

  GeneratedLootData _parseLootFromText(String text, int level) {
    // Try to extract JSON from text
    try {
      // Simple extraction - in production use proper JSON parsing
      final nameMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(text);
      final typeMatch = RegExp(r'"type"\s*:\s*"([^"]+)"').firstMatch(text);
      final statMatch = RegExp(r'"statBoost"\s*:\s*(\d+)').firstMatch(text);
      final descMatch = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(text);

      if (nameMatch != null && typeMatch != null && statMatch != null) {
        final typeStr = typeMatch.group(1)!.toUpperCase();
        EquipmentSlot? type;
        switch (typeStr) {
          case 'BOOTS':
            type = EquipmentSlot.boots;
            break;
          case 'ACCESSORY':
            type = EquipmentSlot.accessory;
            break;
          case 'HELMET':
            type = EquipmentSlot.helmet;
            break;
          case 'ARMOR':
            type = EquipmentSlot.armor;
            break;
          case 'PANTS':
            type = EquipmentSlot.pants;
            break;
          case 'GLOVES':
            type = EquipmentSlot.gloves;
            break;
        }

        if (type != null) {
          return GeneratedLootData(
            name: nameMatch.group(1)!,
            type: type,
            statBoost: int.parse(statMatch.group(1)!),
            description: descMatch?.group(1) ?? "Um item épico!",
          );
        }
      }
    } catch (e) {
      // Fall through to fallback
    }

    return _generateFallbackLoot(level);
  }

  GeneratedLootData _generateFallbackLoot(int level) {
    return GeneratedLootData(
      name: "Artefato Antigo",
      type: EquipmentSlot.accessory,
      statBoost: 5 + (level ~/ 2),
      description: "Um item misterioso encontrado no escuro.",
    );
  }
}

