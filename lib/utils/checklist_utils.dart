class ChecklistItem {
  bool checked;
  String text;

  ChecklistItem({required this.checked, required this.text});
}

class ChecklistUtils {
  static final _itemPattern = RegExp(r'^- \[(x| )\] (.*)$', caseSensitive: false);

  static List<ChecklistItem> parse(String content) {
    if (content.trim().isEmpty) {
      return [ChecklistItem(checked: false, text: '')];
    }
    final lines = content.split('\n');
    final items = <ChecklistItem>[];
    for (final line in lines) {
      final match = _itemPattern.firstMatch(line.trim());
      if (match != null) {
        items.add(ChecklistItem(
          checked: match.group(1)!.toLowerCase() == 'x',
          text: match.group(2) ?? '',
        ));
      } else if (line.trim().isNotEmpty) {
        items.add(ChecklistItem(checked: false, text: line.trim()));
      }
    }
    return items.isEmpty ? [ChecklistItem(checked: false, text: '')] : items;
  }

  static String serialize(List<ChecklistItem> items) {
    return items
        .map((i) => '- [${i.checked ? 'x' : ' '}] ${i.text.trim()}')
        .join('\n');
  }

  static String textToChecklist(String text) {
    if (text.trim().isEmpty) return '- [ ] ';
    final lines = text.split('\n');
    return lines.map((l) => '- [ ] ${l.trim()}').join('\n');
  }
}
