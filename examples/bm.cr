require "benchmark"
require "file_utils"
require "../src/lmdb"

path = "./tmp/bmdb"
count = 1_000_000

FileUtils.rm_r(path) if Dir.exists?(path)
Dir.mkdir_p(path)

puts GC.stats

LMDB.open(path, LMDB.env_flags(NoSync, NoTls), map_size: 256 * 1024 * 1024, max_dbs: 10) do |env|
  db = env.database("wrapper", LMDB.db_flags(Create, IntegerKey))
  db2 = env.database("raw", LMDB.db_flags(Create, IntegerKey))

  Benchmark.bm do |x|
    x.report("writes") do
      (0..count).each do |i|
        env.transaction(on: db) { db[i] = i }
      end
    end

    x.report("raw writes") do
      (0..count).each do |i|
        LibLMDB.txn_begin(env, nil, 0, out txn)
        key = LibLMDB::Val.new
        key.size = sizeof(Int32)
        key.data = pointerof(i).as(UInt8*)
        val = LibLMDB::Val.new
        val.size = sizeof(Int32)
        val.data = pointerof(i).as(UInt8*)
        LibLMDB.put(txn, db2, pointerof(key), pointerof(val), 0)
        LibLMDB.txn_commit(txn)
      end
    end

    x.report("batch writes") do
      env.transaction(on: db) do
        (count..count*2).each do |i|
          db[i] = i
        end
      end
    end

    x.report("raw batch writes") do
      LibLMDB.txn_begin(env, nil, 0, out txn)
      (count..count*2).each do |i|
        key = LibLMDB::Val.new
        key.size = sizeof(Int32)
        key.data = pointerof(i).as(UInt8*)
        val = LibLMDB::Val.new
        val.size = sizeof(Int32)
        val.data = pointerof(i).as(UInt8*)
        LibLMDB.put(txn, db2, pointerof(key), pointerof(val), 0)
      end
      LibLMDB.txn_commit(txn)
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
