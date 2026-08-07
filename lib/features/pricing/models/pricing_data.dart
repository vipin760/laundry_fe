// Enums
enum ServiceType { instant, scheduled }

// Models
class Package {
  final String name;
  final String instantPrice;
  final String scheduledPrice;

  const Package({
    required this.name,
    required this.instantPrice,
    required this.scheduledPrice,
  });
}

class Plan {
  final String name;
  final String price;

  const Plan({
    required this.name,
    required this.price,
  });
}

class Membership {
  final String name;
  final int itemCount;
  final String price;
  final List<String>? conditions;
  final bool unavailable;

  const Membership({
    required this.name,
    required this.itemCount,
    required this.price,
    this.conditions,
    this.unavailable = false,
  });
}

class SmartPass {
  final List<String> includes;
  final String coverage;
  final int validityDays;
  final List<String> excluded;

  const SmartPass({
    required this.includes,
    required this.coverage,
    required this.validityDays,
    required this.excluded,
  });
}

class Note {
  final String text;
  final String category;

  const Note({
    required this.text,
    required this.category,
  });
}

// ============================================================================
// PRICING DATA
// ============================================================================

// Ironing / Shoe Cleaning / Dry Cleaning / Wash & Fold / Wash & Iron / Iron
// Pass / Smart Pass pricing is now dynamic — see
// features/pricing/providers/cloth_types_provider.dart, and how
// pricing_screen.dart builds Package/Plan/Membership/SmartPass instances from
// ClothTypeModel data for each of those categories. Only plain policy/notes
// copy (not prices) remains static here.
class PricingData {
  // WASH & FOLD - NOTES
  static const List<Note> washFoldNotes = [
    Note(
      text: 'Up to 15 garments per 3 KG',
      category: 'washFold',
    ),
    Note(
      text: 'Fair usage applies',
      category: 'washFold',
    ),
    Note(
      text: 'Min order ₹249',
      category: 'washFold',
    ),
    Note(
      text: 'Below ₹249 → ₹49 delivery charge',
      category: 'washFold',
    ),
  ];

  // IMPORTANT NOTES
  static const List<Note> importantNotes = [
    Note(
      text: 'Fair usage applies (10–15 garments per 3 KG)',
      category: 'general',
    ),
    Note(
      text: 'Light items may be counted as additional weight',
      category: 'general',
    ),
    Note(
      text: 'Linen items may attract premium pricing',
      category: 'general',
    ),
    Note(
      text: 'Delicate fabrics may attract premium pricing',
      category: 'general',
    ),
    Note(
      text: 'Silk items require special handling',
      category: 'general',
    ),
    Note(
      text: 'Express services depend on slot availability',
      category: 'general',
    ),
    Note(
      text: 'Curtains are charged per panel',
      category: 'general',
    ),
    Note(
      text: 'Heavy curtain fabrics may have additional charges',
      category: 'general',
    ),
    Note(
      text: 'Ironing available only for flat linen items',
      category: 'general',
    ),
    Note(
      text: 'Bulky household items are folded for best care',
      category: 'general',
    ),
  ];
}
