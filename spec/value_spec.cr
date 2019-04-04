require "./spec_helper"

describe LMDB::Value do
  describe "#initialize" do
    it "can be initialized from a pointer to a primitive type" do
      a = 1u8
      LMDB::Value.new(pointerof(a)).as_u8.should eq(1u8)
      b = 1u16
      LMDB::Value.new(pointerof(b)).as_u16.should eq(1u16)
      c = 1u32
      LMDB::Value.new(pointerof(c)).as_u32.should eq(1u32)
      d = 1u64
      LMDB::Value.new(pointerof(d)).as_u64.should eq(1u64)
      e = 1i8
      LMDB::Value.new(pointerof(e)).as_i8.should eq(1i8)
      f = 1i16
      LMDB::Value.new(pointerof(f)).as_i16.should eq(1i16)
      g = 1i32
      LMDB::Value.new(pointerof(g)).as_i32.should eq(1i32)
      h = 1i64
      LMDB::Value.new(pointerof(h)).as_i64.should eq(1i64)
      i = true
      LMDB::Value.new(pointerof(i)).as_bool.should eq(true)
      j = 1f32
      LMDB::Value.new(pointerof(j)).as_f32.should eq(1f32)
      k = 1f64
      LMDB::Value.new(pointerof(k)).as_f64.should eq(1f64)
      l = 'c'
      LMDB::Value.new(pointerof(l)).as_char.should eq('c')
    end

    it "can be initialized from a slice" do
      slice = Slice(Int32).new(3) { |i| i + 10 }
      value = LMDB::Value.new(slice)
      value.size.should eq(3 * sizeof(Int32))
      value.data.address.should eq(slice.to_unsafe.address)
    end

    it "can be initialized from an array" do
      ary = Array(Int32).new(3) { |i| i + 10 }
      value = LMDB::Value.new(ary)
      value.size.should eq(3 * sizeof(Int32))
      value.data.address.should eq(ary.to_unsafe.address)
    end

    it "can be initialized from a string" do
      str = "Hello, world"
      value = LMDB::Value.new(str)
      value.size.should eq(str.bytesize)
      value.data.address.should eq(str.to_unsafe.address)
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
      val.as_value(Int64).should eq(1i64)
    end

    it "fails if type size doesn't match" do
      val = LMDB::Value.new(1i64)
      expect_raises(Exception) do
        val.as_i
      end
    end
  end

  describe "#string" do
    it "returns a string" do
      str = "Hello, World!"
      val = LMDB::Value.new(str)
      val.as_str.should eq("Hello, World!")
    end
  end

  describe "#array" do
    it "returns an array" do
      vals = [1, 2, 3]
      val = LMDB::Value.new(vals)
      val.as_array(Int32).should eq([1, 2, 3])
    end
  end

  describe "#slice" do
    it "returns a slice" do
      vals = Slice.new(3) { |i| i + 10 }
      val = LMDB::Value.new(vals)
      val.as_slice(Int32).should eq(Slice.new(3) { |i| i + 10 })
    end
  end
end
