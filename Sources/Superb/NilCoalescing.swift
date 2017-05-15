// Source: https://oleb.net/blog/2016/12/optionals-string-interpolation/

infix operator ??? : NilCoalescingPrecedence

func ??? <Value> (value: Value?, defaultDescription: @autoclosure () -> String) -> String {
  return value.map(String.init(describing:)) ?? defaultDescription()
}
