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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// play-services-location 21.4.0 (pulled in by maplibre_gl) is built with
// Kotlin 2.3; this project's Kotlin plugin is 2.1. 21.3.0 has the API
// geolocator/maplibre use. Applies to plugin subprojects too.
subprojects {
    configurations.all {
        resolutionStrategy.force("com.google.android.gms:play-services-location:21.3.0")
    }
}
