require "db"
require "./lmdb/lib_lmdb"
require "./lmdb/types"
require "./lmdb/error"
require "./lmdb/disposable"
require "./lmdb/database"
require "./lmdb/transaction"
require "./lmdb/cursor"
require "./lmdb/environment"

module LMDB
  VERSION = "0.1.0"

  # Returns a tuple of integers describing the LMBD library version that the
  # binding is linked against. The version of the binding itself is available
  # from the `VERSION` constant.
  def self.library_version : Tuple(Int32, Int32, Int32)
    LibLMDB.version(out major, out minor, out patch)
    {major, minor, patch}
  end

  # Open and yields an LMDB database `Environment`. The environment is closed
  # when the block goes out of scope.
  #
  # Example:
  # ```
  # LMDB.open("mydbdir") do |env|
  #   # ...
  # end
  # ```
  #
  # See `Environment#new`.
  def self.open(path : String, flags : Environment::Flag = env_flags(NoTls),
                mode = FileMode.new(0o644), max_dbs : Int = 0, map_size : Int = 0)
    env = Environment.new(path, flags, mode, max_dbs, map_size)
    yield env
  ensure
    env.close if env
  end
end
