require "../src/lmdb"
require "file_utils"

path = "./tmp/anagramsdb"
FileUtils.rm_r(path) if Dir.exists?(path)
Dir.mkdir_p(path)
file = ARGV[1]? || "/usr/share/dict/words"

LMDB.open(path, map_size: 256*1024*1024) do |env|
  db = nil

  env.transaction do |transaction|
    db = LMDB::MultiMapDatabase(String, String).new(env, transaction)
    puts db.flags

    File.each_line(file) do |line|
      word = line.chomp.downcase
      key = word.chars.sort.join
      db.put(key, word)
    end
  end

  if db
    env.transaction(on: db, readonly: true) do
      db.each do |key, val|
        puts "'#{key}' => '#{val}'"
      end
    end
  end
end
