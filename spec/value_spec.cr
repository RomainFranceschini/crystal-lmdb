require "./spec_helper"

describe LMDB::Value do
  describe "#initialize" do
    it "can be initialized from a primitive type" do
      a = 1u8
      LMDB::Value.new(1u8).should eq(LMDB::Value.new(1, pointerof(a).as(UInt8*)))
      b = 1u16
      LMDB::Value.new(1u16).should eq(LMDB::Value.new(2, pointerof(b).as(UInt8*)))
      c = 1u32
      LMDB::Value.new(1u32).should eq(LMDB::Value.new(4, pointerof(c).as(UInt8*)))
      d = 1u64
      LMDB::Value.new(1u64).should eq(LMDB::Value.new(8, pointerof(d).as(UInt8*)))
      e = 1i8
      LMDB::Value.new(1i8).should eq(LMDB::Value.new(1, pointerof(e).as(UInt8*)))
      f = 1i16
      LMDB::Value.new(1i16).should eq(LMDB::Value.new(2, pointerof(f).as(UInt8*)))
      g = 1i32
      LMDB::Value.new(1i32).should eq(LMDB::Value.new(4, pointerof(g).as(UInt8*)))
      h = 1i64
      LMDB::Value.new(1i64).should eq(LMDB::Value.new(8, pointerof(h).as(UInt8*)))
      i = true
      LMDB::Value.new(true).should eq(LMDB::Value.new(1, pointerof(i).as(UInt8*)))
      j = 1f32
      LMDB::Value.new(1f32).should eq(LMDB::Value.new(4, pointerof(j).as(UInt8*)))
      k = 1f64
      LMDB::Value.new(1f64).should eq(LMDB::Value.new(8, pointerof(k).as(UInt8*)))
      l = 'c'
      LMDB::Value.new('c').should eq(LMDB::Value.new(4, pointerof(l).as(UInt8*)))
    end

    it "can be initialized from a pointer to a primitive type" do
      a = 1u8
      LMDB::Value.new(pointerof(a)).should eq(LMDB::Value.new(a))
      b = 1u16
      LMDB::Value.new(pointerof(b)).should eq(LMDB::Value.new(b))
      c = 1u32
      LMDB::Value.new(pointerof(c)).should eq(LMDB::Value.new(c))
      d = 1u64
      LMDB::Value.new(pointerof(d)).should eq(LMDB::Value.new(d))
      e = 1i8
      LMDB::Value.new(pointerof(e)).should eq(LMDB::Value.new(e))
      f = 1i16
      LMDB::Value.new(pointerof(f)).should eq(LMDB::Value.new(f))
      g = 1i32
      LMDB::Value.new(pointerof(g)).should eq(LMDB::Value.new(g))
      h = 1i64
      LMDB::Value.new(pointerof(h)).should eq(LMDB::Value.new(h))
      i = true
      LMDB::Value.new(pointerof(i)).should eq(LMDB::Value.new(i))
      j = 1f32
      LMDB::Value.new(pointerof(j)).should eq(LMDB::Value.new(j))
      k = 1f64
      LMDB::Value.new(pointerof(k)).should eq(LMDB::Value.new(k))
      l = 'c'
      LMDB::Value.new(pointerof(l)).should eq(LMDB::Value.new(l))
    end

    it "can be initialized from a slice" do
      slice = Slice(Int32).new(3) { |i| i + 10 }
      value = LMDB::Value.new(slice)
      value.size.should eq(3 * sizeof(Int32))
      value.mv_data.address.should eq(slice.to_unsafe.address)
    end

    it "can be initialized from an array" do
      ary = Array(Int32).new(3) { |i| i + 10 }
      value = LMDB::Value.new(ary)
      value.size.should eq(3 * sizeof(Int32))
      value.mv_data.address.should eq(ary.to_unsafe.address)
    end

    it "can be initialized from a string" do
      str = "Hello, world"
      value = LMDB::Value.new(str)
      value.size.should eq(str.bytesize)
      value.mv_data.address.should eq(str.to_unsafe.address)
    end
  end

  describe "#==" do
    it "compares based based on data contents" do
      LMDB::Value.new(1i64).should_not eq(LMDB::Value.new(1))
      LMDB::Value.new(1i64).should eq(LMDB::Value.new(1i64))
    end
  end

  describe "#value" do
    it "returns the value" do
      val = LMDB::Value.new(1i64)
      val.value(Int64).should eq(1i64)
    end

    it "fails if type size doesn't match" do
      val = LMDB::Value.new(1i64)
      expect_raises(Exception) do
        val.value(Int32)
      end
    end
  end

  describe "#string" do
    it "returns a string" do
      str = "Hello, World!"
      val = LMDB::Value.new(str)
      val.string.should eq("Hello, World!")
    end
  end

  describe "#array" do
    it "returns an array" do
      vals = [1, 2, 3]
      val = LMDB::Value.new(vals)
      val.array(Int32).should eq([1, 2, 3])
    end
  end

  describe "#slice" do
    it "returns a slice" do
      vals = Slice.new(3) { |i| i + 10 }
      val = LMDB::Value.new(vals)
      val.slice(Int32).should eq(Slice.new(3) { |i| i + 10 })
    end
  end
end
