pub fn uniform(a: Double, b: Double) -> Double {
  a + (b - a) * rand::float64() // rand::float64() 返回 [0,1) 的 Double 类型
}

// 高斯分布: 使用 Box-Muller 变换
pub fn gaussian(mu: Double, sigma: Double) -> Double {
  let u1 = rand::float64()
  let u2 = rand::float64()
  let z0 = sqrt(-2.0 * ln(u1)) * cos(2.0 * pi * u2)
  mu + sigma * z0
}

// 计算样本平均值
pub fn mean(data: Array[Double]) -> Double {
  if data.length() == 0 {
    return 0.0 // 或者抛出错误，取决于期望行为
  }
  var sum = 0.0
  for x in data {
    sum = sum + x
  }
  sum / (data.length() as Double)
}

// 计算样本方差 (无偏估计)
pub fn variance(data: Array[Double]) -> Double {
  if data.length() <= 1 {
    return 0.0 // 或者抛出错误，方差对单个或无数据点无定义
  }
  let m = mean(data)
  var sum_sq = 0.0
  for x in data {
    sum_sq = sum_sq + (x - m) * (x - m)
  }
  sum_sq / ((data.length() - 1) as Double)
}

// 主程序示例: 演示各函数的使用
fn main -> Unit {
  // 演示均匀分布
  let a = 0.0
  let b = 1.0
  println("uniform(0,1) = ${uniform(a, b)}")

  // 演示高斯分布
  println("gaussian(0,1) = ${gaussian(0.0, 1.0)}")

  // 示例数据集
  let data: Array[Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
  println("data = ${data}")
  println("mean(data) = ${mean(data)}")
  println("variance(data) = ${variance(data)}")
}

// 单元测试模块

// 测试 mean 和 variance 函数
test "mean and variance" -> Result[Unit, String] {
  // 经典示例: 数据 [2,4,4,4,5,5,7,9], 平均值 5, 方差 4
  let d: Array[Double] = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
  assert_eq(mean(d), 5.0)?
  assert_eq(variance(d), 4.0)?
  Ok(())
}

// 测试 uniform 在范围内
test "uniform range" -> Result[Unit, String] {
  let x = uniform(5.0, 10.0)
  assert(x >= 5.0 && x < 10.0, "uniform value out of range")?
  Ok(())
}