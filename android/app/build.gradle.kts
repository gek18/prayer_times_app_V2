plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wisam.salatTime"
    compileSdk = 36
    ndkVersion = "21.2.13676358"

    defaultConfig {
        applicationId = "com.wisam.salatTime"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        //  لتجنب أخطاء تعدد ملفات Dex
        multiDexEnabled = true
    }

    buildFeatures {
        viewBinding = true
    }

    //  منع ضغط ملفات الصوت داخل APK
    androidResources {
        noCompress += listOf("mp3", "wav", "ogg")
    }

    //  إعدادات Java & Desugar لتشغيل Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // مجلدات الموارد (Resources)
    sourceSets {
        getByName("main") {
            res.srcDirs("src/main/res", "src/main/res/raw")
        }
    }

    //  أنواع البناء
    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")

            //  إصلاح أخطاء DEX المحتملة
            multiDexKeepProguard = file("multidex-config.pro")
        }
    }

    //  تعطيل توقف Lint في حال وجود تحذيرات
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    //  استبعاد الملفات المكررة من المكتبات
    packaging {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module",
                "META-INF/*.version",
                "META-INF/*.properties"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    //  دعم تعدد DEX لتفادي أخطاء build المستقبلية
    implementation("androidx.multidex:multidex:2.0.1")

    //  مكتبة desugar لتوافق Java 17
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
