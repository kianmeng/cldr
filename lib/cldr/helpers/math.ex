defmodule Cldr.Math do
  @moduledoc """
  Math helper functions for number formatting
  """
  alias Cldr.Digits


  @type number_or_decimal :: number | %Decimal{}
  @type normalised_decimal :: {%Decimal{}, integer}
  @default_rounding 3
  @zero Decimal.new(0)
  @one Decimal.new(1)
  @two Decimal.new(2)
  @minus_one Decimal.new(-1)
  @ten Decimal.new(10)
  @ascii_0 48

  @doc """
  Returns the default rounding used by Cldr.
  """
  @spec default_rounding :: integer
  def default_rounding do
    @default_rounding
  end

  @doc """
  Check if a `number` is within a `range`.

  * `number` is either an integer or a float.

  When an integer, the comparison is made using the standard Elixir `in`
  operator.

  When `number` is a float the comparison is made using the `>=` and `<=`
  operators on the range endpoints. Note the comparison for a float is only for
  floats that have no fractional part. If a float has a fractional part then
  `within` returns `false`.

  *Since this function is only provided to support plural rules, the float
  comparison is only useful if the float has no fractional part.*

  ## Examples

      iex> Cldr.Math.within(2.0, 1..3)
      true

      iex> Cldr.Math.within(2.1, 1..3)
      false
  """
  @spec within(number, integer) :: boolean
  def within(number, range) when is_integer(number) do
    number in range
  end

  # When checking if a decimal is in a range it is only
  # valid if there are no decimal places
  def within(number, first..last) when is_float(number) do
    number == trunc(number) && number >= first && number <= last
  end

  @doc """
  Calculates the modulo of a number (integer, float or Decimal).

  Note that this function uses `floored division` whereas the builtin `rem`
  function uses `truncated division`. See `Decimal.rem/2` if you want a
  `truncated division` function for Decimals that will return the same value as
  the BIF `rem/2` but in Decimal form.

  See [Wikipedia](https://en.wikipedia.org/wiki/Modulo_operation) for an
  explanation of the difference.

  ## Examples

      iex> Cldr.Math.mod(1234.0, 5)
      4.0

      iex> Cldr.Math.mod(Decimal.new("1234.456"), 5)
      #Decimal<4.456>

      iex> Cldr.Math.mod(Decimal.new(123.456), Decimal.new(3.4))
      #Decimal<1.056>

      iex> Cldr.Math.mod Decimal.new(123.456), 3.4
      #Decimal<1.056>
  """
  @spec mod(number_or_decimal, number_or_decimal) ::
    float | %Decimal{}

  def mod(number, modulus) when is_float(number) do
    number - (Float.floor(number / modulus) * modulus)
  end

  def mod(number, modulus) when is_integer(number) do
    modulo = number
    |> Kernel./(modulus)
    |> Float.floor
    |> Kernel.*(modulus)

    number - modulo
  end

  def mod(%Decimal{} = number, %Decimal{} = modulus) do
    modulo = number
    |> Decimal.div(modulus)
    |> Decimal.round(0, :floor)
    |> Decimal.mult(modulus)

    Decimal.sub(number, modulo)
  end

  def mod(%Decimal{} = number, modulus) when is_number(modulus) do
    mod(number, Decimal.new(modulus))
  end

  @doc """
  Convert a Decimal to a float

  * `decimal` must be a Decimal

  This is very likely to lose precision - lots of numbers won't
  make the round trip conversion.  Use with care.  Actually, better
  not to use it at all.
  """
  @spec to_float(%Decimal{}) :: float
  def to_float(%Decimal{sign: sign, coef: coef, exp: exp}) do
    sign * coef * 1.0 * :math.pow(10, exp)
  end

  @doc """
  Rounds a number to a specified number of significant digits.

  This is not the same as rounding fractional digits which is performed
  by `Decimal.round/2` and `Float.round`

  * `number` is a float, integer or Decimal

  * `n` is the number of significant digits to which the `number` should be
    rounded

  ## Examples

      iex> Cldr.Math.round_significant(3.14159, 3)
      3.14

      iex> Cldr.Math.round_significant(10.3554, 1)
      10.0

      iex> Cldr.Math.round_significant(0.00035, 1)
      0.0004

  ## More on significant digits

  * 3.14159 has six significant digits (all the numbers give you useful
    information)

  * 1000 has one significant digit (only the 1 is interesting; you don't know
    anything for sure about the hundreds, tens, or units places; the zeroes may
    just be placeholders; they may have rounded something off to get this value)

  * 1000.0 has five significant digits (the ".0" tells us something interesting
    about the presumed accuracy of the measurement being made: that the
    measurement is accurate to the tenths place, but that there happen to be
    zero tenths)

  * 0.00035 has two significant digits (only the 3 and 5 tell us something; the
    other zeroes are placeholders, only providing information about relative
    size)

  * 0.000350 has three significant digits (that last zero tells us that the
    measurement was made accurate to that last digit, which just happened to
    have a value of zero)

  * 1006 has four significant digits (the 1 and 6 are interesting, and we have
    to count the zeroes, because they're between the two interesting numbers)

  * 560 has two significant digits (the last zero is just a placeholder)

  * 560.0 has four significant digits (the zero in the tenths place means that
    the measurement was made accurate to the tenths place, and that there just
    happen to be zero tenths; the 5 and 6 give useful information, and the
    other zero is between significant digits, and must therefore also be
    counted)

  Many thanks to [Stackoverflow](http://stackoverflow.com/questions/202302/rounding-to-an-arbitrary-number-of-significant-digits)
  """
  @spec round_significant(number_or_decimal, integer) :: number_or_decimal
  def round_significant(number, n) when is_number(number) do
    sign = if number < 0, do: -1, else: 1
    number = abs(number)
    d = Float.ceil(:math.log10(number))
    power = n - d

    magnitude = :math.pow(10, power)
    shifted = Float.round(number * magnitude)
    rounded = shifted / magnitude

    sign * if is_integer(number) do
      trunc(rounded)
    else
      rounded
    end
  end

  def round_significant(%Decimal{sign: sign} = number, n) when sign < 0 do
    round_significant(Decimal.abs(number), n)
    |> Decimal.minus
  end

  def round_significant(%Decimal{sign: sign} = number, n) when sign > 0 do
    d = number
    |> log10
    |> Decimal.round(0, :ceiling)

    raised = n
    |> Decimal.new
    |> Decimal.sub(d)

    magnitude = power(@ten, raised)
    shifted = number
    |> Decimal.mult(magnitude)
    |> Decimal.round(0)

    Decimal.div(shifted, magnitude)
    |> Decimal.mult(Decimal.new(sign))
  end

  @doc """
  Return the natural log of a number.

  * `number` is an integer, a float or a Decimal

  * For integer and float it calls the BIF `:math.log10/1` function.

  * For Decimal the log is rolled by hand.

  ## Examples

      iex> Cldr.Math.log(123)
      4.812184355372417

      iex> Cldr.Math.log(Decimal.new(9000))
      #Decimal<9.103886231350952380952380952>
  """
  @spec log(number_or_decimal) :: number_or_decimal
  def log(number) when is_number(number) do
    :math.log(number)
  end

  @ln10 Decimal.new(2.30258509299)
  def log(%Decimal{} = number) do
    {mantissa, exp} = mantissa_exponent(number)
    exp = Decimal.new(exp)
    ln1 = Decimal.mult(exp, @ln10)

    sqrt_mantissa = sqrt(mantissa)
    y = Decimal.div(Decimal.sub(sqrt_mantissa, @one),
                    Decimal.add(sqrt_mantissa, @one))

    ln2 = y
    |> log_polynomial([3,5,7])
    |> Decimal.add(y)
    |> Decimal.mult(@two)

    Decimal.add(Decimal.mult(@two, ln2), ln1)
  end

  defp log_polynomial(%Decimal{} = value, iterations) do
    Enum.reduce iterations, @zero, fn (i, acc) ->
      i = Decimal.new(i)

      value
      |> power(i)
      |> Decimal.div(i)
      |> Decimal.add(acc)
    end
  end

  @doc """
  Return the log10 of a number.

  * `number` is an integer, a float or a Decimal

    * For integer and float it calls the BIF `:math.log10/1` function.

    * For `Decimal`, `log10` is is rolled by hand using the identify `log10(x) =
    ln(x) / ln(10)`

  ## Examples

      iex> Cldr.Math.log10(100)
      2.0

      iex> Cldr.Math.log10(123)
      2.089905111439398

      iex> Cldr.Math.log10(Decimal.new(9000))
      #Decimal<3.953767554157656512064441441>
  """
  @spec log10(number_or_decimal) :: number_or_decimal
  def log10(number) when is_number(number) do
    :math.log10(number)
  end

  def log10(%Decimal{} = number) do
    Decimal.div(log(number), @ln10)
  end

  @doc """
  Raises a number to a integer power.

  Raises a number to a power using the the binary method. There is one
  exception for Decimal numbers that raise `10` to some power. In this case the
  power is calculated by shifting the Decimal exponent which is quite efficient.

  For further reading see
  [this article](http://videlalvaro.github.io/2014/03/the-power-algorithm.html)

  > This function works only with integer exponents!

  ## Examples

      iex> Cldr.Math.power(10, 2)
      100

      iex> Cldr.Math.power(10, 3)
      1000

      iex> Cldr.Math.power(10, 4)
      10000

      iex> Cldr.Math.power(2, 10)
      1024
  """

  # Decimal number and decimal n
  @spec power(number_or_decimal, number_or_decimal) :: number_or_decimal
  def power(%Decimal{} = _number, %Decimal{coef: n}) when n == 0 do
    @one
  end

  def power(%Decimal{} = number, %Decimal{coef: n}) when n == 1 do
    number
  end

  def power(%Decimal{} = number, %Decimal{sign: sign} = n) when sign < 1 do
    Decimal.div(@one, do_power(number, n, mod(n, @two)))
  end

  def power(%Decimal{} = number, %Decimal{} = n) do
    do_power(number, n, mod(n, @two))
  end

  # Decimal number and integer/float n
  def power(%Decimal{} = _number, n) when n == 0 do
    @one
  end

  def power(%Decimal{} = number, n) when n == 1 do
    number
  end

  # For a decimal we can short cut the multiplications by just
  # adjusting the exponent when the coefficient is 10
  def power(%Decimal{coef: 10, sign: sign, exp: exp}, n) do
    %Decimal{coef: 10, sign: sign, exp: exp + n - 1}
  end

  def power(%Decimal{} = number, n) when n > 1 do
    do_power(number, n, mod(n, 2))
  end

  def power(%Decimal{} = number, n) when n < 0 do
    Decimal.div(@one, do_power(number, abs(n), mod(abs(n), 2)))
  end

  # For integers and floats
  def power(number, n) when n == 0 do
    if is_integer(number), do: 1, else: 1.0
  end

  def power(number, n) when n == 1 do
    number
  end

  def power(number, n) when n > 1 do
    do_power(number, n, mod(n, 2))
  end

  def power(number, n) when n < 1 do
     1 / do_power(number, abs(n), mod(abs(n), 2))
  end

  # Decimal number and decimal n
  defp do_power(%Decimal{} = number, %Decimal{coef: coef}, %Decimal{coef: mod})
  when mod == 0 and coef == 2 do
    Decimal.mult(number, number)
  end

  defp do_power(%Decimal{} = number, %Decimal{coef: coef} = n, %Decimal{coef: mod})
  when mod == 0 and coef != 2 do
    power(power(number, Decimal.div(n, @two)), @two)
  end

  defp do_power(%Decimal{} = number, %Decimal{} = n, _mod) do
    Decimal.mult(number, power(number, Decimal.sub(n, @one)))
  end

  # Decimal number but integer n
  defp do_power(%Decimal{} = number, n, mod)
  when is_number(n) and mod == 0 and n == 2 do
    Decimal.mult(number, number)
  end

  defp do_power(%Decimal{} = number, n, mod)
  when is_number(n) and mod == 0 and n != 2 do
    power(power(number, n / 2), 2)
  end

  defp do_power(%Decimal{} = number, n, _mod)
  when is_number(n) do
    Decimal.mult(number, power(number, n - 1))
  end

  # integer/float number and integer/float n
  defp do_power(number, n, mod)
  when is_number(n) and mod == 0 and n == 2 do
    number * number
  end

  defp do_power(number, n, mod)
  when is_number(n) and mod == 0 and n != 2 do
    power(power(number, n / 2), 2)
  end

  defp do_power(number, n, _mod) do
    number * power(number, n - 1)
  end

  @doc """
  Returns a tuple representing a Decimal in a normalized form with
  the mantissa in the range `0 < m < 10` and a base 10 exponent.

  * `number` is an integer, float or Decimal

  ## Examples

      Cldr.Math.mantissa_exponent(Decimal.new(1.23004))
      {#Decimal<1.23004>, 0}

      Cldr.Math.mantissa_exponent(Decimal.new(465))
      {#Decimal<4.65>, 2}

      Cldr.Math.mantissa_exponent(Decimal.new(-46.543))
      {#Decimal<-4.6543>, 1}
  """
  @spec mantissa_exponent(%Decimal{}) :: normalised_decimal
  def mantissa_exponent(number, meta \\ %{fractional_digits: %{max: 0}})
  def mantissa_exponent(%Decimal{} = number, %{fractional_digits: %{max: 0}}) do
    if between_one_and_minus_one(number) do
      coef_digits = Digits.number_of_integer_digits(number.coef)
      leading_zeros = abs(number.exp) - coef_digits
      exp = -(leading_zeros + 1)
      mantissa = %Decimal{number | exp: -coef_digits + 1}
      {Digits.to_tuple(mantissa), exp}
    else
      coef_digits = Digits.number_of_integer_digits(number.coef)
      exp = coef_digits + number.exp - 1
      mantissa = %Decimal{number | exp: number.exp - exp}
      {Digits.to_tuple(mantissa), exp}
    end
  end

  def mantissa_exponent(number, %{fractional_digits: %{max: 0}})
  when is_float(number) do
    {integer, exp} = to_mantissa_exponent(number)

    if between_one_and_minus_one(number) do
      coef_digits = Digits.number_of_integer_digits(integer)
      mantissa = integer / :math.pow(10, coef_digits - 1)
      {Digits.to_tuple(mantissa), exp - 1}
    else
      coef_digits = Digits.number_of_integer_digits(integer)
      exp = coef_digits - exp
      mantissa = integer / :math.pow(10, coef_digits - 1)
      {Digits.to_tuple(mantissa), exp}
    end
  end

  def mantissa_exponent(number, %{fractional_digits: _fractional_digits})
  when is_integer(number) do
    coef_digits = Digits.number_of_integer_digits(number)
    exp = coef_digits - 1
    mantissa = number / exp
    {mantissa, exp}
  end


  defp to_mantissa_exponent(float) do
    {int_digits, exp, _sign} = Digits.to_digits(float)
    integer = int_digits
    |> Enum.map(&Kernel.+(&1, @ascii_0))
    |> List.to_integer

    {integer, exp}
  end

  defp between_one_and_minus_one(%Decimal{} = number) do
    (Decimal.cmp(number, @minus_one) == :gt && Decimal.cmp(number, @one) == :lt)
    || Decimal.cmp(number, @one) == :eq
    || Decimal.cmp(number, @minus_one) == :eq
  end

  defp between_one_and_minus_one(number) do
    number >= -1.0 and number <= 1.0
  end

  @doc """
  Calculates the square root of a Decimal number using Newton's method.

  * `number` must be a `Decimal`

  We convert the Decimal to a float and take its
  `:math.sqrt` only to get an initial estimate.
  The means typically we are only two iterations from
  a solution so the slight hack improves performance
  without sacrificing precision.

  ## Examples

      iex> Cldr.Math.sqrt(Decimal.new(9))
      #Decimal<3.0>

      iex> Cldr.Math.sqrt(Decimal.new(9.869))
      #Decimal<3.141496458696078173887197038>
  """
  @precision 0.0001
  @decimal_precision Decimal.new(@precision)
  def sqrt(number, precision \\ @precision)

  def sqrt(%Decimal{sign: sign} = number, _precision)
  when sign == -1 do
    raise ArgumentError, "bad argument in arithmetic expression #{inspect number}"
  end

  # Get an initial estimate of the sqrt by using the built in `:math.sqrt`
  # function.  This means typically its only two iterations to get the default
  # the sqrt at the specified precision.
  def sqrt(%Decimal{} = number, precision)
  when is_number(precision) do
    initial_estimate = number
    |> to_float
    |> :math.sqrt
    |> Decimal.new

    decimal_precision = Decimal.new(precision)
    do_sqrt(number, initial_estimate, @decimal_precision, decimal_precision)
  end

  def sqrt(number, _precision) do
    :math.sqrt(number)
  end

  defp do_sqrt(%Decimal{} = number, %Decimal{} = estimate,
      %Decimal{} = old_estimate, %Decimal{} = precision) do
    diff = estimate
    |> Decimal.sub(old_estimate)
    |> Decimal.abs

    if Decimal.cmp(diff, old_estimate) == :lt
       || Decimal.cmp(diff, old_estimate) == :eq do
      estimate
    else
      Decimal.div(number, Decimal.mult(@two, estimate))
      new_estimate = Decimal.add(Decimal.div(estimate, @two),
        Decimal.div(number, Decimal.mult(@two, estimate)))
      do_sqrt(number, new_estimate, estimate, precision)
    end
  end

  @doc """
  Calculate the nth root of a number.

  * `number` is an integer or a Decimal

  * `nth` is a positive integer

  ## Examples

      iex> Cldr.Math.root Decimal.new(8), 3
      #Decimal<2.0>

      iex> Cldr.Math.root Decimal.new(16), 4
      #Decimal<2.0>

      iex> Cldr.Math.root Decimal.new(27), 3
      #Decimal<3.0>
  """
  def root(%Decimal{} = number, nth) when is_integer(nth) and nth > 0 do
    guess = :math.pow(to_float(number), 1 / nth)
    |> Decimal.new

    do_root number, Decimal.new(nth), guess
  end

  def root(number, nth) when is_number(number) and is_integer(nth) and nth > 0 do
    guess = :math.pow(number, 1 / nth)
    do_root number, nth, guess
  end

  @root_precision 0.0001
  defp do_root(number, nth, root) when is_number(number) do
    delta = (1 / nth) * (number / :math.pow(root, nth - 1)) - root
    if delta > @root_precision do
      do_root(number, nth, root + delta)
    else
      root
    end
  end

  @decimal_root_precision Decimal.new(@root_precision)
  defp do_root(%Decimal{} = number, %Decimal{} = nth, %Decimal{} = root) do
    d1 = Decimal.div(@one, nth)
    d2 = Decimal.div(number, power(root, Decimal.sub(nth, @one)))
    d3 = Decimal.sub(d2, root)
    delta = Decimal.mult(d1, d3)

    if Decimal.cmp(delta, @decimal_root_precision) == :gt do
      do_root(number, nth, Decimal.add(root, delta))
    else
      root
    end
  end
end