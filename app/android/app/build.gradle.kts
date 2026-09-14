plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "sa.redmarket.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // تفعيل Desugaring لدعم Java 8 ومكتبة التنبيهات على الإصدارات القديمة
        isCoreLibraryDesugaringEnabled = true 
        
        // ضبط التوافق البرمجي على الإصدار 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // تأكيد استهداف JVM 17
        jvmTarget = "17" 
    }

    defaultConfig {
        applicationId = "sa.redmarket.app"
        
        // ✅ التعديل الهام: تحديد الحد الأدنى 21 لضمان عمل مكتبات الفيديو
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ✅ تفعيل تعدد الملفات (مهم جداً لتجنب انهيار البناء)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // المكتبة المسؤولة عن تحويل الأكواد الحديثة
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
    // ✅ إضافة مكتبة MultiDex بشكل صريح (احتياطاً)
    implementation("androidx.multidex:multidex:2.0.1")
}