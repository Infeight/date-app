# --- AndroidX WorkManager / Room (fixes "Failed to create an instance of
# androidx.work.impl.WorkDatabase" release-only crash) ---
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keepclassmembers @androidx.room.Entity class * {
    <init>(...);
}
-dontwarn androidx.work.**
-dontwarn androidx.room.**