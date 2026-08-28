# HMS Core Push Kit ProGuard rules
# Keep HMS SDK classes from being stripped by R8

# Huawei Push Kit
-keep class com.huawei.hms.** { *; }
-keep class com.huawei.hms.push.** { *; }
-keep class com.huawei.hms.support.** { *; }
-keep class com.huawei.hms.adapter.** { *; }
-keep class com.huawei.hms.framework.** { *; }
-keep class com.huawei.hms.utils.** { *; }
-keep class com.huawei.hms.common.** { *; }
-keep class com.huawei.hms.network.** { *; }

# Huawei Analytics (required by HMS Push internally)
-keep class com.huawei.hianalytics.** { *; }
-keep class com.huawei.hianalytics.process.** { *; }
-keep class com.huawei.hianalytics.util.** { *; }
-dontwarn com.huawei.hianalytics.**

# Huawei Secure Android (encryption utils)
-keep class com.huawei.secure.android.common.** { *; }
-dontwarn com.huawei.secure.android.common.**

# BouncyCastle (used by HMS Secure Android)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Huawei device-specific classes (only available on Huawei devices at runtime)
-keep class com.huawei.android.os.BuildEx$VERSION { *; }
-dontwarn com.huawei.android.os.BuildEx$VERSION

# Huawei external storage (only available on Huawei devices at runtime)
-keep class com.huawei.libcore.io.** { *; }
-dontwarn com.huawei.libcore.io.**

# HMS Update Adapter
-keep class com.huawei.hms.availableupdate.** { *; }
-dontwarn com.huawei.hms.availableupdate.**

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }
