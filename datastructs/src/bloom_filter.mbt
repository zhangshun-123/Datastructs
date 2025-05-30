pub struct BloomFilter {
  bitset: Array[Bool] // 位数组，True 表示可能存在
  size: Int           // 位数组长度
  hash_count: Int     // 哈希函数个数 (k)
}

// 构造函数：创建大小为 `size`，k 个哈希函数的 BloomFilter
pub fn new(size: Int, hash_count: Int) -> BloomFilter {
  // 实际应用中，应检查 size > 0 和 hash_count > 0
  BloomFilter { bitset: Array::make(size, false), size, hash_count }
}

// 私有方法：根据不同种子生成 hash 值
fn hash_idx(data: String, seed: Int, array_size: Int) -> Int {
  let data_bytes = data.to_bytes()
  // murmur3 的 seed 是 UInt32
  let h_u32 = murmur3(data_bytes, seed.to_uint())
  // 确保 array_size 转为 UInt32 进行取模，以得到非负索引
  (h_u32 % (array_size.to_uint())) as Int
}

// 添加元素到过滤器
pub fn add(bf: BloomFilter, item: String) -> Unit {
  for i in 0 ..< bf.hash_count {
    let idx = hash_idx(item, i, bf.size)
    bf.bitset[idx] = true
  }
}

// 检查某个元素是否可能存在
pub fn contains(bf: BloomFilter, item: String) -> Bool {
  for i in 0 ..< bf.hash_count {
    let idx = hash_idx(item, i, bf.size)
    if not(bf.bitset[idx]) {
      return false   // 一定不存在
    }
  }
  true  // 可能存在
}

// 主程序示例：演示如何使用 BloomFilter
fn main -> Unit {
  // 创建一个大小为 100，使用 3 个哈希函数的 BloomFilter
  let bf = new(100, 3)

  // 添加一些元素
  add(mut bf, "apple")
  add(mut bf, "banana")

  // 查询元素
  println("apple 可能存在? ${contains(&bf, "apple")}")
  println("banana 可能存在? ${contains(&bf, "banana")}")
  println("orange 可能存在? ${contains(&bf, "orange")}")
}

// 单元测试：验证 BloomFilter 的基本行为
test "bloom filter add and contains" -> Result[Unit, String] {
  // 初始化
  var bf = new(16, 2)

  // 初始时不包含 'x'
  assert_eq(contains(&bf, "x"), false)?

  // 添加 'x' 后应检测到
  add(&mut bf, "x")
  assert_eq(contains(&bf, "x"), true)?

  // 重复添加相同元素仍然返回 true
  add(&mut bf, "x")
  assert_eq(contains(&bf, "x"), true)?
  Ok(())
}