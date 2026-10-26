/// Euros the Slovenian way: a dot for thousands, a comma for cents.
/// `115000` → `€1.150`, `9950` → `€99,50`, `-2000` → `−€20`.
String formatEuros(int? cents) {
  if (cents == null) {
    return '';
  }
  final negative = cents < 0;
  final abs = cents.abs();
  final euros = abs ~/ 100;
  final rest = abs % 100;
  final digits = euros.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      grouped.write('.');
    }
    grouped.write(digits[i]);
  }
  final cent = rest == 0 ? '' : ',${rest.toString().padLeft(2, '0')}';
  return '${negative ? '−' : ''}€$grouped$cent';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `26 Oct 2026`.
String formatDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// `2012-05-01` → `1 May 2012`; anything else is returned as given.
String formatIsoDate(String? iso) {
  if (iso == null || iso.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? iso : formatDate(parsed);
}
