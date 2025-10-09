String redact(String? s, {int head = 4, int tail = 2}) {
  if (s == null || s.isEmpty) return '';
  if (s.length <= head + tail) return '••••';
  return '${s.substring(0, head)}•••${s.substring(s.length - tail)}';
}


