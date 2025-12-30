//  الجذر العام لمشروع الأندرويد
import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    // تعريف المتغيرات التي تحتاجها بعض الإضافات القديمة (مثل geolocator_android)
    extra.apply {
        set("compileSdkVersion", 36)
        set("targetSdkVersion", 36)
        set("minSdkVersion", 23)
        set("kotlin_version", "2.1.0")
    }

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.7.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

//  تغيير مسار build directory (من Flutter)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

//  بعض الإضافات تتطلب التأكد من تقييم app قبل البقية
subprojects {
    project.evaluationDependsOn(":app")
}

//  أمر clean لحذف مجلدات build
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
