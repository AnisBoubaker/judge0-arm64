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
  go = @languages.find { |language| language[:id] == 60 }
  go[:compile_cmd] = "GOMAXPROCS=2 GOCACHE=/tmp/.cache/go-build /usr/local/go-1.13.5/bin/go build -p 1 %s main.go" if go

  java = @languages.find { |language| language[:id] == 62 }
  if java
    java[:compile_cmd] = "/usr/local/openjdk13/bin/javac -J-Xms8m -J-Xmx64m -J-XX:+UseSerialGC -J-XX:MaxMetaspaceSize=64m -J-XX:CompressedClassSpaceSize=16m -J-XX:ReservedCodeCacheSize=32m -J-XX:ActiveProcessorCount=1 %s Main.java"
    java[:run_cmd] = "/usr/local/openjdk13/bin/java -Xms8m -Xmx64m -XX:+UseSerialGC -XX:MaxMetaspaceSize=64m -XX:CompressedClassSpaceSize=16m -XX:ReservedCodeCacheSize=32m -XX:ActiveProcessorCount=1 Main"
  end
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
