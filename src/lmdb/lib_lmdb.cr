@[Link("lmdb")]
lib LibLMDB
  FIXEDMAP    =        1
  NOSUBDIR    =    16384
  NOSYNC      =    65536
  RDONLY      =   131072
  NOMETASYNC  =   262144
  WRITEMAP    =   524288
  MAPASYNC    =  1048576
  NOTLS       =  2097152
  NOLOCK      =  4194304
  NORDAHEAD   =  8388608
  NOMEMINIT   = 16777216
  REVERSEKEY  =        2
  DUPSORT     =        4
  INTEGERKEY  =        8
  DUPFIXED    =       16
  INTEGERDUP  =       32
  REVERSEDUP  =       64
  CREATE      =   262144
  NOOVERWRITE =       16
  NODUPDATA   =       32
  CURRENT     =       64
  RESERVE     =    65536
  APPEND      =   131072
  APPENDDUP   =   262144
  MULTIPLE    =   524288
  CP_COMPACT  =        1
  SUCCESS     =        0

  # alias Env = Void
  # alias Txn = Void
  # alias Cursor = Void

  # alias X__Uint16T = LibC::UShort
  # alias X__DarwinModeT = X__Uint16T
  # alias ModeT = X__DarwinModeT
  alias ModeT = LibC::UShort # ModeT
  alias FilehandleT = LibC::Int
  alias Dbi = LibC::UInt

  alias Txn = Void*
  alias Cursor = Void*
  alias Env = Void*

  struct Val
    size : LibC::SizeT
    data : Void*
  end

  struct Stat
    psize : LibC::UInt
    depth : LibC::UInt
    branch_pages : LibC::SizeT
    leaf_pages : LibC::SizeT
    overflow_pages : LibC::SizeT
    entries : LibC::SizeT
  end

  struct Envinfo
    mapaddr : Void*
    mapsize : LibC::SizeT
    last_pgno : LibC::SizeT
    last_txnid : LibC::SizeT
    maxreaders : LibC::UInt
    numreaders : LibC::UInt
  end

  enum CursorOp
    First        =  0
    FirstDup     =  1
    GetBoth      =  2
    GetBothRange =  3
    GetCurrent   =  4
    GetMultiple  =  5
    Last         =  6
    LastDup      =  7
    Next         =  8
    NextDup      =  9
    NextMultiple = 10
    NextNodup    = 11
    Prev         = 12
    PrevDup      = 13
    PrevNodup    = 14
    Set          = 15
    SetKey       = 16
    SetRange     = 17
    PrevMultiple = 18
  end

  fun version = mdb_version(major : LibC::Int*, minor : LibC::Int*, patch : LibC::Int*) : LibC::Char*
  fun strerror = mdb_strerror(err : LibC::Int) : LibC::Char*
  fun env_create = mdb_env_create(env : Env*) : LibC::Int
  fun env_open = mdb_env_open(env : Env, path : LibC::Char*, flags : LibC::UInt, mode : ModeT) : LibC::Int
  fun env_copy = mdb_env_copy(env : Env, path : LibC::Char*) : LibC::Int
  fun env_copyfd = mdb_env_copyfd(env : Env, fd : FilehandleT) : LibC::Int
  fun env_copy2 = mdb_env_copy2(env : Env, path : LibC::Char*, flags : LibC::UInt) : LibC::Int
  fun env_copyfd2 = mdb_env_copyfd2(env : Env, fd : FilehandleT, flags : LibC::UInt) : LibC::Int
  fun env_stat = mdb_env_stat(env : Env, stat : Stat*) : LibC::Int
  fun env_info = mdb_env_info(env : Env, stat : Envinfo*) : LibC::Int
  fun env_sync = mdb_env_sync(env : Env, force : LibC::Int) : LibC::Int
  fun env_close = mdb_env_close(env : Env)
  fun env_set_flags = mdb_env_set_flags(env : Env, flags : LibC::UInt, onoff : LibC::Int) : LibC::Int
  fun env_get_flags = mdb_env_get_flags(env : Env, flags : LibC::UInt*) : LibC::Int
  fun env_get_path = mdb_env_get_path(env : Env, path : LibC::Char**) : LibC::Int
  fun env_get_fd = mdb_env_get_fd(env : Env, fd : FilehandleT*) : LibC::Int
  fun env_set_mapsize = mdb_env_set_mapsize(env : Env, size : LibC::SizeT) : LibC::Int
  fun env_set_maxreaders = mdb_env_set_maxreaders(env : Env, readers : LibC::UInt) : LibC::Int
  fun env_get_maxreaders = mdb_env_get_maxreaders(env : Env, readers : LibC::UInt*) : LibC::Int
  fun env_set_maxdbs = mdb_env_set_maxdbs(env : Env, dbs : Dbi) : LibC::Int
  fun env_get_maxkeysize = mdb_env_get_maxkeysize(env : Env) : LibC::Int
  fun env_set_userctx = mdb_env_set_userctx(env : Env, ctx : Void*) : LibC::Int
  fun env_get_userctx = mdb_env_get_userctx(env : Env) : Void*
  fun env_set_assert = mdb_env_set_assert(env : Env, func : (Env, LibC::Char* -> Void)) : LibC::Int
  fun txn_begin = mdb_txn_begin(env : Env, parent : Txn, flags : LibC::UInt, txn : Txn*) : LibC::Int
  fun txn_env = mdb_txn_env(txn : Txn) : Env
  fun txn_id = mdb_txn_id(txn : Txn) : LibC::SizeT
  fun txn_commit = mdb_txn_commit(txn : Txn) : LibC::Int
  fun txn_abort = mdb_txn_abort(txn : Txn)
  fun txn_reset = mdb_txn_reset(txn : Txn)
  fun txn_renew = mdb_txn_renew(txn : Txn) : LibC::Int
  fun dbi_open = mdb_dbi_open(txn : Txn, name : LibC::Char*, flags : LibC::UInt, dbi : Dbi*) : LibC::Int
  fun stat = mdb_stat(txn : Txn, dbi : Dbi, stat : Stat*) : LibC::Int
  fun dbi_flags = mdb_dbi_flags(txn : Txn, dbi : Dbi, flags : LibC::UInt*) : LibC::Int
  fun dbi_close = mdb_dbi_close(env : Env, dbi : Dbi)
  fun drop = mdb_drop(txn : Txn, dbi : Dbi, del : LibC::Int) : LibC::Int
  fun set_compare = mdb_set_compare(txn : Txn, dbi : Dbi, cmp : (Val*, Val* -> LibC::Int)) : LibC::Int
  fun set_dupsort = mdb_set_dupsort(txn : Txn, dbi : Dbi, cmp : (Val*, Val* -> LibC::Int)) : LibC::Int
  fun set_relfunc = mdb_set_relfunc(txn : Txn, dbi : Dbi, rel : (Val*, Void*, Void*, Void* -> Void)) : LibC::Int
  fun set_relctx = mdb_set_relctx(txn : Txn, dbi : Dbi, ctx : Void*) : LibC::Int
  fun get = mdb_get(txn : Txn, dbi : Dbi, key : Val*, data : Val*) : LibC::Int
  fun put = mdb_put(txn : Txn, dbi : Dbi, key : Val*, data : Val*, flags : LibC::UInt) : LibC::Int
  fun del = mdb_del(txn : Txn, dbi : Dbi, key : Val*, data : Val*) : LibC::Int
  fun cursor_open = mdb_cursor_open(txn : Txn, dbi : Dbi, cursor : Cursor*) : LibC::Int
  fun cursor_close = mdb_cursor_close(cursor : Cursor)
  fun cursor_renew = mdb_cursor_renew(txn : Txn, cursor : Cursor) : LibC::Int
  fun cursor_txn = mdb_cursor_txn(cursor : Cursor) : Txn
  fun cursor_dbi = mdb_cursor_dbi(cursor : Cursor) : Dbi
  fun cursor_get = mdb_cursor_get(cursor : Cursor, key : Val*, data : Val*, op : CursorOp) : LibC::Int
  fun cursor_put = mdb_cursor_put(cursor : Cursor, key : Val*, data : Val*, flags : LibC::UInt) : LibC::Int
  fun cursor_del = mdb_cursor_del(cursor : Cursor, flags : LibC::UInt) : LibC::Int
  fun cursor_count = mdb_cursor_count(cursor : Cursor, countp : LibC::SizeT*) : LibC::Int
  fun cmp = mdb_cmp(txn : Txn, dbi : Dbi, a : Val*, b : Val*) : LibC::Int
  fun dcmp = mdb_dcmp(txn : Txn, dbi : Dbi, a : Val*, b : Val*) : LibC::Int
  fun reader_list = mdb_reader_list(env : Env, func : (LibC::Char*, Void* -> LibC::Int), ctx : Void*) : LibC::Int
  fun reader_check = mdb_reader_check(env : Env, dead : LibC::Int*) : LibC::Int
end
