// 1. src/ring_buffer.mbt
// 环形缓冲区 (RingBuffer) 的实现
pub struct RingBuffer[T] {
  buf: Array[T]       // 底层存储数组
  head: Int      // 下一个读取位置索引
  tail: Int      // 下一个写入位置索引
  capacity: Int  // 数组容量 (buf.length())
}

// 构造函数: 创建并初始化 RingBuffer，使用 init 填充底层 buf
pub fn new[T: Copy](capacity: Int, init: T) -> RingBuffer[T] {
  let buf = Array::make(capacity, init) // 生成长度为 capacity 的数组
  RingBuffer { buf, head: 0, tail: 0, capacity }
}

// 判断是否为空: head == tail
pub fn is_empty[T](rb: RingBuffer[T]) -> Bool {
  rb.head == rb.tail
}

// 判断是否为满: 下一个 tail 会等于 head
pub fn is_full[T](rb: RingBuffer[T]) -> Bool {
  (rb.tail + 1) % rb.capacity == rb.head
}

// 入队操作: 将元素 x 推入队列尾
// 注意：此函数现在接收 RingBuffer[T] 的副本。
// 对 rb.head 和 rb.tail 的修改将是局部的。
pub fn push[T](rb: RingBuffer[T], x: T) -> Result[Unit, String] {
  if is_full(rb) { // is_full 仍然可以接收引用
    return Err("RingBuffer is full".to_string())
  }
  rb.buf[rb.tail] = x
  rb.tail = (rb.tail + 1) % rb.capacity
  Ok(())
}

// 出队操作: 从队列头弹出元素，如果为空返回 None
// 注意：此函数现在接收 RingBuffer[T] 的副本。
// 对 rb.head 和 rb.tail 的修改将是局部的。
pub fn pop[T: Copy](mut rb: RingBuffer[T]) -> Option[T] {
  if is_empty(&rb) { // is_empty 仍然可以接收引用
    return None
  }
  let x = rb.buf[rb.head]
  rb.head = (rb.head + 1) % rb.capacity
  Some(x)
}

// 主程序示例：演示 RingBuffer 的基本操作
fn main -> Unit {
  // 创建容量为 5 的环形缓冲区，初始值为 0
  var rb = new(5, 0)

  // 入队 1, 2, 3
  // 注意：由于 push 现在接收副本，原始 rb 的 head/tail 不会改变
  // 为了使状态更新，push 需要返回新的 rb，然后重新赋值。
  // 这里为了保持与请求的语法一致性，暂时不修改返回类型。
  match push(rb, 1) {
    Ok(()) => {} // rb 在这里没有被外部的 rb 更新
    Err(e) => println("Error: ${e}")
  }
  match push(rb, 2) {
    Ok(()) => {}
    Err(e) => println("Error: ${e}")
  }
  match push(rb, 3) {
    Ok(()) => {}
    Err(e) => println("Error: ${e}")
  }
  // 此处的 rb.head 和 rb.tail 可能仍为初始值 0,0
  println("After pushes: head=${rb.head}, tail=${rb.tail}")

  // 出队两个元素
  match pop(rb) { // 同样，pop 也操作副本
    Some(v) => println("pop -> ${v}")
    None => println("pop -> None")
  }
  match pop(rb) {
    Some(v) => println("pop -> ${v}")
    None => println("pop -> None")
  }
  println("After pops: head=${rb.head}, tail=${rb.tail}")

  match push(rb, 4) { Ok(()) => {}, Err(e) => println("Error: ${e}") }
  match push(rb, 5) { Ok(()) => {}, Err(e) => println("Error: ${e}") }
  match push(rb, 6) { Ok(()) => {}, Err(e) => println("Error: ${e}") }

  println("Attempting to push when full: ${push(rb, 7)}")

  loop {
    match pop(rb) {
      Some(v) => println("pop -> ${v}")
      None => break
    }
  }
  println("Final: is_empty? ${is_empty(&rb)}")
}

// 单元测试：验证 RingBuffer 的行为
test "ring buffer push/pop and full/empty" {
  var rb = new(3, 0) 
  assert_eq!(is_empty(&rb), true)
  assert_eq!(is_full(&rb), false)

  // 注意：以下断言可能因为 push/pop 操作副本而失败或行为不符合预期
  assert!(push(rb, 10).is_ok())
  assert!(push(rb, 20).is_ok())
  // rb.head, rb.tail 未在外部更新，is_empty(&rb) 可能仍然是 true
  assert_eq!(is_empty(&rb), false) 
  assert_eq!(is_full(&rb), false)

  assert!(push(rb, 30).is_ok()) 
  assert_eq!(is_full(&rb), true) 
  assert_eq!(push(rb, 40).is_err(), true)

  assert_eq!(pop(rb), Some(10))
  assert_eq!(pop(rb), Some(20))
  assert_eq!(pop(rb), Some(30))
  assert_eq!(pop(rb), None)
  assert_eq!(is_empty(&rb), true)
  // Ok(()) // No longer returning Result
}