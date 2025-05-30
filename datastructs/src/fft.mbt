
pub struct Complex {
  re: Double
  im: Double
}

pub fn Complex::new(re: Double, im: Double) -> Complex {
  { re, im }
}

pub fn Complex::add(self: Complex, other: Complex) -> Complex {
  Complex::new(self.re + other.re, self.im + other.im)
}

pub fn Complex::sub(self: Complex, other: Complex) -> Complex {
  Complex::new(self.re - other.re, self.im - other.im)
}

pub fn Complex::mul(self: Complex, other: Complex) -> Complex {
  Complex::new(
    self.re * other.re - self.im * other.im,
    self.re * other.im + self.im * other.re,
  )
}

// 计算 e^(i * θ)
fn exp_i(theta: Double) -> Complex {
  Complex::new(cos(theta), sin(theta))
}

// 辅助函数：检查 n 是否为 2 的幂
fn is_power_of_two(n: Int) -> Bool {
  n > 0 && (n & (n - 1)) == 0
}

// 递归 FFT：输入长度必须是 2 的幂
pub fn fft(input: Array[Complex]) -> Array[Complex] {
  let n = input.length()
  assert(is_power_of_two(n), "Input length must be a power of two")

  if n == 1 {
    return [input[0]] // 直接创建包含单个元素的数组
  }

  let half = n / 2
  let even: Array[Complex] = [] // 初始化空数组
  let odd: Array[Complex] = []  // 初始化空数组

  for i in 0 .. half {
    even.push(input[2 * i])
    odd.push(input[2 * i + 1])
  }

  let fft_even = fft(even)
  let fft_odd = fft(odd)

  var result = Array::make(n, Complex::new(0.0, 0.0)) // 初始化结果数组
  for k in 0 ..< half {
    let angle = -2.0 * pi * (k as Double) / (n as Double)
    let twiddle = exp_i(angle)
    let t = fft_odd[k].mul(twiddle) // 调用 Complex 的 mul 方法
    result[k] = fft_even[k].add(t)
    result[k + half] = fft_even[k].sub(t)
  }
  result
}

fn main -> Unit {
  // 示例：8 点序列 (0,1,0,-1,0,1,0,-1)
  let input: Array[Complex] = [
    Complex::new(0.0, 0.0),
    Complex::new(1.0, 0.0),
    Complex::new(0.0, 0.0),
    Complex::new(-1.0, 0.0),
    Complex::new(0.0, 0.0),
    Complex::new(1.0, 0.0),
    Complex::new(0.0, 0.0),
    Complex::new(-1.0, 0.0),
  ]
  let output = fft(input)
  // Moonbit 的 println 使用 ${} 进行插值，它会使用 Complex 的 Debug 特质
  println("FFT output: ${output}")
}

// 辅助函数：比较复数是否近似相等（考虑浮点精度）
fn complex_approx_eq(a: Complex, b: Complex, epsilon: Double) -> Bool {
  abs(a.re - b.re) < epsilon && abs(a.im - b.im) < epsilon
}

// 单元测试
test "fft_of_constant_signal_corrected" -> Result[Unit, String] {
  // 输入为常数序列 [1,1,1,1,1,1,1,1]
  // 预期 FFT 输出为 [8,0,0,0,0,0,0,0]
  let input = Array::make(8, Complex::new(1.0, 0.0))
  let out = fft(input)
  let epsilon = 1e-9 // 容差

  debug::assert(complex_approx_eq(out[0], Complex::new(8.0, 0.0), epsilon), "DC component mismatch")?
  for i in 1 .. out.length() {
    debug::assert(complex_approx_eq(out[i], Complex::new(0.0, 0.0), epsilon), "AC component ${i} should be zero, got ${out[i]}")?
  }
  Ok(())
}

test "fft_of_delta_function" -> Result[Unit, String] {
  // 输入为单位脉冲序列 [1,0,0,0,0,0,0,0]
  var input = Array::make(8, Complex::new(0.0, 0.0))
  input[0] = Complex::new(1.0, 0.0)
  let out = fft(input)
  let epsilon = 1e-9
  // 预期 FFT 输出为 [1,1,1,1,1,1,1,1]
  for v in out {
    debug::assert(complex_approx_eq(v, Complex::new(1.0, 0.0), epsilon), "Element ${v} not close to 1.0+0.0i")?
  }
  Ok(())
}

test "fft_main_example_check" -> Result[Unit, String] {
  // 验证 main 函数中使用的示例
  let input: Array[Complex] = [
    Complex::new(0.0, 0.0), Complex::new(1.0, 0.0), Complex::new(0.0, 0.0), Complex::new(-1.0, 0.0),
    Complex::new(0.0, 0.0), Complex::new(1.0, 0.0), Complex::new(0.0, 0.0), Complex::new(-1.0, 0.0),
  ]
  let output = fft(input)
  // 预期 FFT 输出为 [0, 0, -4i, 0, 0, 0, 4i, 0]
  let expected_output: Array[Complex] = [
    Complex::new(0.0, 0.0), Complex::new(0.0, 0.0), Complex::new(0.0, -4.0), Complex::new(0.0, 0.0),
    Complex::new(0.0, 0.0), Complex::new(0.0, 0.0), Complex::new(0.0, 4.0),  Complex::new(0.0, 0.0),
  ]
  let epsilon = 1e-9

  debug::assert(output.length() == expected_output.length(), "Output length mismatch")?
  for i in 0 .. output.length() {
    debug::assert(complex_approx_eq(output[i], expected_output[i], epsilon),
           "FFT output mismatch at index ${i}: got ${output[i]}, expected ${expected_output[i]}")?
  }
  Ok(())
}