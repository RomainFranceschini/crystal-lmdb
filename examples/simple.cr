require "../src/lmdb"
require "file_utils"

# Example from https://www.youtube.com/watch?v=Rx1-in-a1Xc
# 08:21

path = "./tmp/simpledb"
FileUtils.rm_r(path) if Dir.exists?(path)
Dir.mkdir_p(path)

LMDB.open("./tmp/simpledb", max_dbs: 10) do |env|
  env.open_db do |db|
    db.put('a', 'a'.ord)
    db.put('b', 'b'.ord)
    db.put('c', 'c'.ord)

    db.put("string", 6)
    db.put(42, "Meaning of life")

    db.put("Hello", "World")

    db.put("array", [1, 2, 3, 4, 5])

    puts db.get('a').as_i
    puts db.get("string").as_i
    puts db.get(42).as_str
    puts db.get("array").as_slice(Int32)

    db.delete("Hello")
    db.delete('b')

    pp db.get?("Hello") # => nil
    pp db.get?('b')     # => nil
  end

  env.open_db("cursor", LMDB.db_flags(Create)) do |db|
    255.times { |i| db.put(i, i.chr) }

    db.each do |key, val|
      puts "'#{val.as_char}' => #{key.as_i}"
    end
  end
end
