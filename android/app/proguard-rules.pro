# ML Kit text-recognition: abaikan class model bahasa opsional yang tidak
# di-bundle (Chinese, Devanagari, Japanese, Korean). Kita hanya pakai
# model Latin default, jadi class ini tidak pernah dipanggil saat runtime.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
