# ML Kit missing language modules workaround
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# 保留 ML Kit 核心
-keep class com.google.mlkit.** { *; }