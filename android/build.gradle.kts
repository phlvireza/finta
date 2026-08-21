allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Align every plugin module's Java and Kotlin JVM targets with the app's.
//
// Several plugins still declare `jvmTarget = 1.8` and `sourceCompatibility =
// VERSION_1_8` in their own build.gradle (flutter_timezone 3.0.1 is the one
// that fails the build; share_plus and file_picker apply KGP too). AGP 9
// floors Java at 11 and silently raises those modules' Java tasks, but
// nothing raises their Kotlin task — so `compileReleaseJavaWithJavac` lands
// on 11 while `compileReleaseKotlin` stays on 1.8, and Gradle aborts with
// "Inconsistent JVM-target compatibility".
//
// Pinned to 17 to match android/app/build.gradle.kts rather than to the
// 11 floor: a mixed 11/17 build works, but leaves the same class of
// mismatch one AGP bump away from reappearing.
//
// Remove once these plugins ship versions that target 11+ themselves.
val pluginJvmTarget = JavaVersion.VERSION_17

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = pluginJvmTarget
                targetCompatibility = pluginJvmTarget
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(pluginJvmTarget.toString()),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
