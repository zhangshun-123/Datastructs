// 5. src/matrix.mbt
// 简单矩阵运算库

pub struct Matrix {
  rows: Int         // 行数
  cols: Int         // 列数
  data: Array[Double]    // 行优先存储，长度 = rows * cols
}

// 构造函数：创建 rows x cols 大小的矩阵，并用 init 填充
pub fn new(rows: Int, cols: Int, init: Double) -> Matrix {
  Matrix { rows, cols, data: Array::make(rows * cols, init) }
}

// 获取指定位置 (i,j) 的元素
pub fn get(m: Matrix, i: Int, j: Int) -> Double {
  m.data[i * m.cols + j]
}

// 设置指定位置 (i,j) 的元素
pub fn set(m: Matrix, i: Int, j: Int, v: Double) {
  m.data[i * m.cols + j] = v
}

// 矩阵乘法: a.rows x a.cols 乘以 b.rows x b.cols (要求 a.cols == b.rows)
pub fn mul(a: Matrix, b: Matrix) -> Matrix {
  let mut out = new(a.rows, b.cols, 0.0)
  for i in 0 ..< a.rows {
    for j in 0 ..< b.cols {
      let sum = 0.0
      for k in 0 ..< a.cols {
        sum = sum + get(a, i, k) * get(b, k, j)
      }
      set(&mut out, i, j, sum)
    }
  }
  out
}

// 主程序示例：演示如何使用 new、set、get 和 mul
fn main -> Unit {
  // 构造 2×3 矩阵 A
  var A = new(2, 3, 0.0)
  set(&mut A, 0, 0, 1.0)
  set(&mut A, 0, 1, 2.0)
  set(&mut A, 0, 2, 3.0)
  set(&mut A, 1, 0, 4.0)
  set(&mut A, 1, 1, 5.0)
  set(&mut A, 1, 2, 6.0)

  // 构造 3×2 矩阵 B
  var B = new(3, 2, 0.0)
  set(&mut B, 0, 0, 7.0)
  set(&mut B, 0, 1, 8.0)
  set(&mut B, 1, 0, 9.0)
  set(&mut B, 1, 1, 10.0)
  set(&mut B, 2, 0, 11.0)
  set(&mut B, 2, 1, 12.0)

  // 计算 C = A × B，结果应为 2×2 矩阵
  let C = mul(&A, &B)

  // 打印结果
  println("Matrix C (${C.rows}x${C.cols}):") // Added from previous correct response
  for i in 0 .. C.rows {
    var row_str = ""
    for j in 0 .. C.cols {
      row_str = row_str + get(&C, i, j).to_string() + " "
    }
    println("Row ${i}: ${row_str}") // Changed println format
  }
}

// 单元测试：验证矩阵乘法的正确性
test "matrix multiplication correctness" -> Result[Unit, String] {
  // 2×2 单位矩阵乘以自身仍是单位矩阵
  var I = new(2, 2, 0.0)
  set(&mut I, 0, 0, 1.0)
  set(&mut I, 1, 1, 1.0)

  let out = mul(&I, &I)
  assert_eq!(get(&out, 0, 0), 1.0)?
  assert_eq!(get(&out, 0, 1), 0.0)?
  assert_eq!(get(&out, 1, 0), 0.0)?
  assert_eq!(get(&out, 1, 1), 1.0)?

  // 简单数值测试：[[1,2],[3,4]] × [[5,6],[7,8]]
  let A_test = new(2, 2, 0.0) // Renamed A to A_test to avoid conflict with A in main
  set(&mut A_test, 0, 0, 1.0); set(&mut A_test, 0, 1, 2.0)
  set(&mut A_test, 1, 0, 3.0); set(&mut A_test, 1, 1, 4.0)

  let B_test = new(2, 2, 0.0) // Renamed B to B_test to avoid conflict with B in main
  set(&mut B_test, 0, 0, 5.0); set(&mut B_test, 0, 1, 6.0)
  set(&mut B_test, 1, 0, 7.0); set(&mut B_test, 1, 1, 8.0)

  let C_test = mul(&A_test, &B_test) // Renamed C to C_test to avoid conflict with C in main
  // 验证结果 [[19,22],[43,50]]
  assert_eq!(get(&C_test, 0, 0), 19.0)?
  assert_eq!(get(&C_test, 0, 1), 22.0)?
  assert_eq!(get(&C_test, 1, 0), 43.0)?
  assert_eq!(get(&C_test, 1, 1), 50.0)?
  Ok(())
}