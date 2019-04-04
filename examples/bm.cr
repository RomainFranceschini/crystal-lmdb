require "benchmark"
require "file_utils"
require "../src/lmdb"

path = "./tmp/bmdb"
count = 1_000_000

FileUtils.rm_r(path) if Dir.exists?(path)
Dir.mkdir_p(path)

puts GC.stats

LMDB.open(path, LMDB.env_flags(NoSync, NoTls), map_size: 256 * 1024 * 1024, max_dbs: 10) do |env|
  db = env.open_db("data", LMDB.db_flags(Create, IntegerKey))

  Benchmark.bm do |x|
    x.report("writes") do
      count.times do |i|
        env.transaction(on: db) { db[i] = i }
      end
    end

    x.report("batch writes") do
      env.transaction(on: db) do
        count.times do |i|
          db[i] = i
        end
      end
    end
  end

  Benchmark.bm do |x|
    x.report("reads") do
      count.times do |i|
        env.transaction(on: db, readonly: true) { db[i] }
      end
    end

    x.report("batch reads") do
      env.transaction(on: db, readonly: true) do
        count.times do |i|
          db[i]
        end
      end
    end
  end
end

puts GC.stats
