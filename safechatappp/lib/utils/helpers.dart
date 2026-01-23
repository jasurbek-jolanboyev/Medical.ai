// lib/utils/helpers.dart

String formatViews(int num) {
  if (num < 1000) return num.toString();
  // Masalan: 1500 -> 1.5K
  return "${(num / 1000).toStringAsFixed(1)}K";
}
