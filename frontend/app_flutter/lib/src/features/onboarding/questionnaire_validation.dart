String? questionnaireProblem(Map<String, Map<String, dynamic>> sections) {
  final a = sections['a'] ?? {},
      b = sections['b'] ?? {},
      c = sections['c'] ?? {},
      d = sections['d'] ?? {},
      e = sections['e'] ?? {};
  bool text(Map<String, dynamic> row, String key, int min) =>
      row[key] is String && (row[key] as String).trim().length >= min;
  bool list(Map<String, dynamic> row, String key, int min) =>
      row[key] is List && (row[key] as List).length >= min;
  if (!text(a, 'brand_name', 2) ||
      !text(a, 'one_liner', 10) ||
      !RegExp(
        r'^@?[a-zA-Z0-9._]{1,30}$',
      ).hasMatch('${a['instagram_handle'] ?? ''}'.trim()) ||
      !text(a, 'category', 1) ||
      !text(a, 'primary_goal', 1) ||
      !list(a, 'products', 1) ||
      !text(
        Map<String, dynamic>.from((a['products'] as List).first as Map),
        'name',
        1,
      )) {
    return 'Complete section A: brand, valid Instagram handle, description, category, goal and a product.';
  }
  if (!text(b, 'ideal_customer', 10) ||
      !text(b, 'problem', 10) ||
      !text(b, 'why_chosen', 10) ||
      !list(b, 'languages', 1) ||
      !text(b, 'caption_script', 1)) {
    return 'Complete section B: audience, problem, reasons to choose you (at least 10 characters each), language and caption script.';
  }
  if (!list(c, 'voice_words', 2) || !list(c, 'anti_voice_words', 1)) {
    return 'Complete section C: choose at least two voice words and one word to avoid.';
  }
  if (!text(d, 'brand_guidelines', 1) ||
      !list(d, 'colours', 1) ||
      !list(d, 'visual_direction', 1)) {
    return 'Complete section D: guidelines, at least one brand colour and visual direction.';
  }
  if (!list(e, 'on_camera', 1) ||
      !list(e, 'shoot_locations', 1) ||
      !text(e, 'shoot_city', 2) ||
      !text(e, 'cta_destination', 1)) {
    return 'Complete section E: on-camera participants, shoot location/city and CTA destination.';
  }
  return null;
}
