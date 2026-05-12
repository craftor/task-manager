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
    afterEvaluate {
        // Inject namespace for plugins that don't declare it (AGP 8.x requirement)
        if (hasProperty("android")) {
            try {
                val androidExt = this.extensions.getByName("android")
                val nsMethod = androidExt.javaClass.getMethod("getNamespace")
                val namespace = nsMethod.invoke(androidExt) as? String
                if (namespace.isNullOrEmpty()) {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, project.group.toString())
                }
            } catch (_: Exception) {
                // Fallback: namespace injection failed — not all plugins support it
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
