# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in ${sdk.dir}/tools/proguard/proguard-android.txt

# Keep Node.js native methods
-keep class com.nicollite.nodejs.** { *; }

# Keep engine classes
-keep class org.anchoros.android.engine.** { *; }

# Standard Android optimizations
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose
