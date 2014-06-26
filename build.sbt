name := "databrary"

scalaVersion in ThisBuild := "2.11.1"

scalacOptions in ThisBuild ++= Seq("-target:jvm-1.7","-optimise","-feature","-deprecation","-Xlint","-Yinline-warnings")

// scalacOptions += "-Ymacro-debug-lite"

resolvers in ThisBuild += Resolver.file("Local repo", file(Path.userHome.absolutePath+"/.ivy2/local"))(Resolver.ivyStylePatterns)

scalacOptions in (Compile, doc) <++= baseDirectory.map { bd => Seq(
  "-sourcepath", bd.getAbsolutePath,
  "-doc-source-url", "https://github.com/databrary/databrary/tree/master€{FILE_PATH}.scala"
) }

GitDescribe.gitDescribeOptions in ThisBuild := Seq("--long", "--dirty")

version in ThisBuild <<= GitDescribe.gitDescribe.apply(_.getOrElse("unknown"))

lazy val macros = project

lazy val dbrary = project
  .dependsOn(macros)

lazy val media = project
  .dependsOn(dbrary)

lazy val logbackAccess = project in file("logback-access")

lazy val databrary = (project in file("."))
  .enablePlugins(play.PlayScala)
  .aggregate(macros, dbrary, media, logbackAccess)
  .dependsOn(macros, dbrary, media, logbackAccess)

libraryDependencies ++= Seq(
  "org.mindrot" % "jbcrypt" % "0.3m",
  ws,
  "com.typesafe.play.plugins" %% "play-plugins-mailer" % "2.3.0",
  "org.webjars" % "jquery" % "1.11.0",
  "org.webjars" % "angularjs" % "1.2.18",
  "org.webjars" % "bindonce" % "0.3.1"
)

resourceGenerators in Compile <+= (resourceManaged in Compile, name, version) map { (dir, name, ver) =>
  val f = dir / "properties"
  val content = "name=" + name + "\nversion=" + ver + "\n"
  if (!f.exists || !IO.read(f).equals(content))
    IO.write(f, content)
  Seq(f)
}

TwirlKeys.templateImports ++= Seq("macros._", "site._")

includeFilter in (Assets, LessKeys.less) := "app.less"

PlayKeys.closureCompilerOptions += "ecmascript5_strict"

JSConcatCompiler.externs := Seq(
  url("https://github.com/gsklee/ngStorage/raw/0.3.0/ngStorage.min.js")
)
