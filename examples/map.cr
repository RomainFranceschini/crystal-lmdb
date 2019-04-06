require "../src/lmdb"
require "file_utils"

path = "./tmp/exdb"
FileUtils.rm_r(path) if Dir.exists?(path)
Dir.mkdir_p(path)

LMDB.open(path, max_dbs: 10) do |env|
  db = nil

  env.transaction do |transaction|
    db = LMDB::MapDatabase(Int32, Char).new(env, "ascii", transaction, LMDB.db_flags(Create))
    puts db.flags
    255.times do |i|
      db[i] = i.chr
    end
  end

  if db
    env.transaction(on: db, readonly: true) do
      255.times { |i| print "'#{db[i]}' " }
      puts
    end
  end
end
