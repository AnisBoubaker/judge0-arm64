require_relative 'languages/archived'
require_relative 'languages/active'

enabled_language_ids = ENV.fetch("JUDGE0_ENABLED_LANGUAGE_IDS", "")
  .split(",")
  .filter_map { |id| Integer(id.strip, exception: false) }

if enabled_language_ids.any?
  known_language_ids = @languages.map { |language| language[:id] }
  unknown_language_ids = enabled_language_ids - known_language_ids
  raise "Unknown JUDGE0_ENABLED_LANGUAGE_IDS: #{unknown_language_ids.join(',')}" if unknown_language_ids.any?

  @languages.select! { |language| enabled_language_ids.include?(language[:id]) }
end

if ENV["JUDGE0_ARM64_POC"] == "true"
  c = @languages.find { |language| language[:id] == 50 }
  c&.merge!(name: "C (GCC 13.2.0)", compile_cmd: "/usr/local/gcc-13.2.0/bin/gcc %s main.c")

  cpp = @languages.find { |language| language[:id] == 54 }
  cpp&.merge!(
    name: "C++ (GCC 13.2.0)",
    compile_cmd: "/usr/local/gcc-13.2.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-13.2.0/lib64 ./a.out"
  )

  go = @languages.find { |language| language[:id] == 60 }
  go&.merge!(
    name: "Go (1.22.7)",
    compile_cmd: "GOMAXPROCS=2 GOCACHE=/tmp/.cache/go-build /usr/local/go-1.22.7/bin/go build -p 1 %s main.go"
  )

  java = @languages.find { |language| language[:id] == 62 }
  if java
    java[:name] = "Java (OpenJDK 17.0.12)"
    java[:compile_cmd] = "/usr/local/openjdk17/bin/javac -J-Xms8m -J-Xmx64m -J-XX:+UseSerialGC -J-XX:MaxMetaspaceSize=64m -J-XX:CompressedClassSpaceSize=16m -J-XX:ReservedCodeCacheSize=32m -J-XX:ActiveProcessorCount=1 %s Main.java"
    java[:run_cmd] = "/usr/local/openjdk17/bin/java -Xms8m -Xmx64m -XX:+UseSerialGC -XX:MaxMetaspaceSize=64m -XX:CompressedClassSpaceSize=16m -XX:ReservedCodeCacheSize=32m -XX:ActiveProcessorCount=1 Main"
  end

  javascript = @languages.find { |language| language[:id] == 63 }
  javascript&.merge!(name: "JavaScript (Node.js 22.8.0)", run_cmd: "/usr/local/node-22.8.0/bin/node script.js")

  python = @languages.find { |language| language[:id] == 71 }
  python&.merge!(name: "Python (3.12.7)", run_cmd: "/usr/local/python-3.12.7/bin/python3 script.py")

  rust = @languages.find { |language| language[:id] == 73 }
  rust&.merge!(name: "Rust (1.81.0)", compile_cmd: "/usr/local/rust-1.81.0/bin/rustc %s main.rs")

  typescript = @languages.find { |language| language[:id] == 74 }
  typescript&.merge!(
    name: "TypeScript (5.6.3)",
    compile_cmd: "/usr/bin/tsc --typeRoots /usr/local/lib/node_modules/@types --types node %s script.ts",
    run_cmd: "/usr/local/node-22.8.0/bin/node script.js"
  )
end

ActiveRecord::Base.transaction do
  Language.unscoped.delete_all
  @languages.each_with_index do |language, index|
    Language.create(
      id: language[:id],
      name: language[:name],
      is_archived: language[:is_archived],
      source_file: language[:source_file],
      compile_cmd: language[:compile_cmd],
      run_cmd: language[:run_cmd],
    )
  end
end
