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
// Beberapa plugin masih dikompilasi terhadap SDK lama (mis. file_picker = 34) sementara dependensi lain
// mensyaratkan 36. Samakan semua modul library ke 36. HARUS didaftarkan sebelum evaluationDependsOn.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.LibraryExtension) {
            android.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
