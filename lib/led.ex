defmodule LED do
  @moduledoc """
  [![Build Status](https://github.com/alexisruccius/led/workflows/CI/badge.svg)](https://github.com/alexisruccius/led/actions/workflows/CI.yml)
  [![Hex.pm](https://img.shields.io/hexpm/v/led.svg)](https://hex.pm/packages/led)
  [![API docs](https://img.shields.io/hexpm/v/led.svg?label=hexdocs "API docs")](https://hexdocs.pm/led)
  [![Hex Downloads](https://img.shields.io/hexpm/dt/led)](https://hex.pm/packages/led)
  [![Last Updated](https://img.shields.io/github/last-commit/alexisruccius/led.svg)](https://github.com/alexisruccius/led/commits/master)
  [![GitHub stars](https://img.shields.io/github/stars/alexisruccius/led.svg)](https://github.com/alexisruccius/led/stargazers)

  Control LEDs or relays. A simple library with some artful gimmicks.

  ```elixir
  {:ok, _pid} = LED.start_link()
  LED.blink()
  ```

  This library is a simple, convenient wrapper around [Circuits.GPIO](https://hexdocs.pm/circuits_gpio/)
  for controlling LEDs or relays. Beyond basic on/off control, it enables artful, experimental,
  and even random noise light effects through overlapping repeating patterns — offering creative flexibility.
  Use it with [Nerves](#using-with-nerves).

  ## ✨ Features

  - ⚡ Control single or multiple LEDs or relays on GPIO pins
  - ✔ Easy on/off control
  - ⏰ Blink and repeat patterns with configurable intervals and counts
  - 💡 Toggle LED state
  - 🎛️ Optional named LED processes for multiple devices
  - Supports overlapping repeat patterns for creative effects
  - Defaults to GPIO pin 22 `"GPIO22"` (Raspberry Pi Zero W) with LED initially on

  ## Installation

  Add to your `mix.exs`:

  ```elixir
  def deps do
    [
      {:led, "~> 0.1.0"}
    ]
  end
  ```

  ## ⚙️ Connect LED to Raspberry Pi Zero W (`"GPIO22"`) example

  - Anode (long leg) → GPIO pin 22
  - Cathode (short leg) → 330Ω resistor → GND

  ```shell
  ┌─────┬──────────┬─────────────────────┐
  │ Pin │ Use      │ Connection          │
  ├─────┼──────────┼─────────────────────┤
  │  6    GND        ────────────────┐   │
  │ 15    GPIO22     ───▶|───[330Ω]──┘   │
  └─────┴──────────┴─────────────────────┘
  ```

  ## 🛠 Usage

  ### Start an LED

  * Default (gpio_pin: "GPIO22", initially on):

  ```elixir
  {:ok, _pid} = LED.start_link()
  ```

  * Named (gpio_pin: "GPIO23", initially off):

  ```elixir
  {:ok, _pid} = LED.start_link(name: :green_led, gpio_pin: "GPIO23", initial_value: 0)
  ```

  ### Turn it on or off

  * Default:

  ```elixir
  LED.on()
  LED.off()
  ```
  * Named:

  ```elixir
  LED.on(:green_led)
  LED.off(:green_led)
  ```

  ### Toggle LED

  ```elixir
  LED.toggle()
  LED.toggle(:green_led)
  ```

  ### Set state directly

  ```elixir
  LED.set(0, :green_led)  # Off
  LED.set(1, :green_led)  # On
  ```
  ### ⏰ Blink LED

  * Blink indefinitely at 2 Hz (250ms interval):

  ```elixir
  LED.blink()
  LED.blink(name: :green_led)
  ```

  * Blink LED on default/`:green_led` 10 times, toggling every 500 ms:

  ```elixir
  LED.blink(interval: 500, times: 10)
  LED.blink(name: :green_led, interval: 500, times: 10)
  ```

  ### Repeat blinking (overlapping allowed)

  * Start a repeating blink pattern on default/`:green_led` every 300 ms indefinitely:

  ```elixir
  LED.repeat(interval: 300)
  LED.repeat(name: :green_led, interval: 300)
  ```
  * Overlay multiple blinking patterns (polyrhythmic effect):

  ```elixir
  LED.repeat(interval: 400, times: 5)
  LED.repeat(interval: 700, times: 3)
  LED.repeat(name: :green_led, interval: 400, times: 5)
  LED.repeat(name: :green_led, interval: 700, times: 3)
  ```
  ### Cancel blinking timers

  Stop all blinking/repeating timers on default/`:green_led`:

  ```elixir
  LED.cancel_timers()
  LED.cancel_timers(:green_led)
  ```

  ## Using with Nerves

  You can integrate the `LED` module into your [Nerves](https://hexdocs.pm/nerves/getting-started.html) application's supervision tree.
  For example, to control a LED connected to GPIO pin "GPIO23" (default is "GPIO22"), add the LED process like this:

  ```elixir
  children = [
    {LED, [gpio_pin: "GPIO23"]}
  ]
  ```

  This ensures the LED is supervised and ready to use with functions like `LED.on/0` or `LED.blink/1`.

  💡 Works great on [Nerves-supported devices](https://hexdocs.pm/nerves/supported-targets.html) like Raspberry Pi or BeagleBone.

  ## Disclaimer

    > #### Note on use with relay {: .tip}
    > When using a relay, check its datasheet
    > for minimum switch times to avoid damage or malfunction.
  """
  @moduledoc since: "0.1.0"

  use GenServer

  alias Circuits.GPIO
  alias LED.Timer

  require Logger

  @type t() :: %__MODULE__{
          name: GenServer.name(),
          gpio_pin: GPIO.gpio_spec() | identifier(),
          handle: GPIO.Handle.t(),
          state: 0 | 1,
          timer_refs: reference()
        }
  defstruct name: nil, gpio_pin: nil, handle: nil, state: 0, timer_refs: []

  @typedoc "Options for starting the LED GenServer"
  @type start_options :: [
          {:name, GenServer.name()},
          {:gpio_pin, GPIO.gpio_spec() | identifier()},
          {:initial_value, 0 | 1}
        ]

  @typedoc "Options for blink"
  @type blink_options :: [
          {:interval, pos_integer()},
          {:times, integer()}
        ]

  @typedoc "Options for repeat"
  @type repeat_options :: [
          {:interval, pos_integer()},
          {:times, integer()}
        ]

  @gpio_pin "GPIO22"
  @initial_value 1

  @doc """
  Starts the LED GenServer.

  Accepts keyword arguments in `init_args` to configure the LED:

    * `:name` – Optional name for the GenServer (used for referencing multiple LEDs)
    * `:initial_value` – (0 or 1) Initial LED state; `0` = off, `1` = on (default: `1`)
    * `:gpio_pin` – GPIO pin to control; defaults to `"GPIO22"`.
      Use any of the formats described in the
      [Circuits.GPIO docs](https://hexdocs.pm/circuits_gpio/2.1.2/Circuits.GPIO.html#t:gpio_spec/0).
      You can list available GPIO references with `Circuits.GPIO.enumerate/0`.
      For example, on a Raspberry Pi Zero W:

      ```elixir
      [
        %{label: "GPIO22", location: {"gpiochip0", 22}, controller: "pinctrl-bcm2835"},
        %{label: "GPIO23", location: {"gpiochip0", 23}, controller: "pinctrl-bcm2835"}
      ]
      ```

  ## Examples

  Start the default LED:

      iex> {:ok, _pid} = LED.start_link()

  Start a named LED on pin "GPIO23", initially off.
  You can control it with:

      iex> {:ok, _pid} = LED.start_link(name: :green_led, gpio_pin: "GPIO23", initial_value: 0)
      iex> LED.on(:green_led)
      iex> LED.is_lit?(:green_led)
      true
  """
  @doc since: "0.1.0"
  @spec start_link(start_options()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(init_args \\ []) do
    name = Keyword.get(init_args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

  @doc """
  Turns the LED on by setting its GPIO state to `1`.

  Accepts an optional `name` argument to control a specific LED process started
  with `start_link/1`. If no `name` is given, the default module name is used.

  Calling this will cancel any active blinking or repeat timers before switching
  the LED on.

  ## Examples

  Turn on the default LED (GPIO pin "GPIO22"):

      iex> LED.on()

  Start and turn on a named LED on GPIO pin "GPIO23":

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :led_green)
      iex> LED.on(:led_green)
  """
  @doc since: "0.1.0"
  @spec on(GenServer.name()) :: :ok
  def on(name \\ __MODULE__), do: set(1, name)

  @doc """
  Turns the LED off by setting its GPIO state to `0`.

  Accepts an optional `name` argument to control a specific LED process started
  with `start_link/1`. If no `name` is given, the default module name is used.

  Calling this will cancel any active blinking or repeat timers before switching
  the LED off.

  ## Examples

  Turn off the default LED (GPIO pin "GPIO22"):

      iex> LED.off()

  Start and turn off a named LED on GPIO pin "GPIO23":

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :led_yellow)
      iex> LED.off(:led_yellow)
  """
  @doc since: "0.1.0"
  @spec off(GenServer.name()) :: :ok
  def off(name \\ __MODULE__), do: set(0, name)

  @doc """
  Toggles the LED: turns it off if on, and on if off.

  ## Examples

      iex> {:ok, _pid} = LED.start_link()
      iex> LED.on()
      iex> LED.toggle()
      iex> LED.is_lit?()
      false

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :green_led)
      iex> LED.off(:green_led)
      iex> LED.toggle(:green_led)
      iex> LED.is_lit?(:green_led)
      true
  """
  @doc since: "0.1.0"
  @spec toggle(GenServer.name()) :: :ok
  def toggle(name \\ __MODULE__) do
    if is_lit?(name), do: off(name), else: on(name)
  end

  @doc """
  Returns `true` if the LED is currently on (`state == 1`), otherwise returns `false`.

  Accepts an optional `name` argument for the GenServer process name set via `start_link/1`.
  Defaults to the module name.

  ## Examples

      iex> {:ok, _pid} = LED.start_link()
      iex> LED.on()
      iex> LED.is_lit?()
      true
      iex> LED.off()
      iex> LED.is_lit?()
      false

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :led_pink)
      iex> LED.on(:led_pink)
      iex> LED.is_lit?(:led_pink)
      true
      iex> LED.off(:led_pink)
      iex> LED.is_lit?(:led_pink)
      false
  """
  @doc deprecated: "Use `lit?/1` instead"
  @spec is_lit?(GenServer.name()) :: boolean()
  @doc since: "0.1.0"
  # credo:disable-for-next-line
  def is_lit?(name \\ __MODULE__) do
    %LED{state: state} = :sys.get_state(name)
    state == 1
  end

  @doc """
  Returns `true` if the LED is currently on (`state == 1`), otherwise returns `false`.

  Accepts an optional `name` argument for the GenServer process name set via `start_link/1`.
  Defaults to the module name.

  ## Examples

      iex> {:ok, _pid} = LED.start_link()
      iex> LED.on()
      iex> LED.lit?()
      true
      iex> LED.off()
      iex> LED.lit?()
      false

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :led_pink)
      iex> LED.on(:led_pink)
      iex> LED.lit?(:led_pink)
      true
      iex> LED.off(:led_pink)
      iex> LED.lit?(:led_pink)
      false
  """
  @spec lit?(GenServer.name()) :: boolean()
  @doc since: "0.1.1"
  def lit?(name \\ __MODULE__) do
    %LED{state: state} = :sys.get_state(name)
    state == 1
  end

  @doc """
  Starts or updates regular blinking for the LED.

  Accepts keyword options:

    * `:name` – GenServer name of the LED. Defaults to the module name.
    * `:interval` – (integer) Blink interval in milliseconds. Default is `250` (≈2 Hz).
    * `:times` – (integer) Number of blinks. Default is `-1` for continuous blinking.

  This will cancel any existing blinking or repeat timers before starting.

  Use `repeat/1` instead for experimental or overlapping blink patterns.

  ## Examples

      iex> LED.blink()
      :ok

      iex> LED.blink(name: :green_led, interval: 500, times: 10)
      :ok
  """
  @doc since: "0.1.0"
  @spec blink(blink_options()) :: :ok
  def blink(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    interval = Keyword.get(opts, :interval, 250)
    # -1 is infinite blinking
    times = Keyword.get(opts, :times, -1)

    cancel_timers(name)
    timer_start(interval, times, name)
  end

  @doc """
  Starts a repeating blink pattern on the LED.

  Unlike `blink/1`, this function allows multiple overlapping patterns,
  enabling experimental or polyrhythmic effects. Each call creates a new
  timer without cancelling existing ones.

  Can be manually canceled using `cancel_timers/1`.

  Useful for creative setups or layered visual rhythms. For best visibility,
  use intervals greater than 10ms.

  ## Options

    * `:name` – GenServer name of the LED. Defaults to the module name.
    * `:interval` – (integer) Interval in milliseconds between toggles. Default: `250` (≈2 Hz).
    * `:times` – (integer) Number of blinks. `-1` means infinite. Default: `-1`.

  If you want predictable, single-pattern blinking, use `blink/1` instead.

  ## Examples

      iex> LED.repeat()
      :ok
      iex> LED.repeat(interval: 969)
      :ok
      iex> LED.cancel_timers()

      iex> LED.repeat(name: :green_led, interval: 900)
      :ok
      iex> LED.repeat(name: :green_led, interval: 690)
      :ok
      iex> LED.cancel_timers(:green_led)
  """
  @doc since: "0.1.0"
  @spec repeat(repeat_options()) :: :ok
  def repeat(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    interval = Keyword.get(opts, :interval, 250)
    # -1 is infinite blinking
    times = Keyword.get(opts, :times, -1)

    timer_start(interval, times, name)
  end

  # client casts

  @doc """
  Sets the LED to a specific state: `1` for **on**, `0` for **off**.

  Any active blinking or repeat timers will be canceled before setting the state,
  ensuring full manual control.

  Accepts an optional `name` argument to target a specific LED GenServer.
  If omitted, it uses the default module name.

  ## Examples

  Turn off and on the default LED:

      iex> LED.set(0)
      iex> LED.set(1)

  Control a named LED:

      iex> {:ok, _pid} = LED.start_link(gpio_pin: "GPIO23", name: :led_red)
      iex> LED.set(0, :led_red)
      iex> LED.set(1, :led_red)
  """
  @doc since: "0.1.0"
  @spec set(0 | 1, GenServer.name()) :: :ok
  def set(state, name \\ __MODULE__)

  def set(state, name) when state == 0 or state == 1 do
    cancel_timers(name)
    GenServer.cast(name, {:set, state})
  end

  def set(_state, _name), do: Logger.warning("Only state 0 or 1 allowed in LED.set/2")

  @doc """
  Starts a blinking timer that toggles the LED at a given interval and for a
  given number of times.

  - `interval` – blinking interval in milliseconds.
  - `times` – how often to toggle the LED. Use `-1` for infinite blinking.

  Use `cancel_timers/1` to stop the blinking manually.

  ## Examples

  Blink the default LED continuously every 200ms:

      iex> LED.timer_start(200, -1)

  Blink a named LED 5 times every 300ms:

      iex> LED.timer_start(300, 5, :led_blue)
  """
  @doc since: "0.1.0"
  @spec timer_start(integer(), integer(), GenServer.name()) :: :ok
  def timer_start(interval, times \\ -1, name \\ __MODULE__) do
    GenServer.cast(name, {:timer_start, interval, times})
  end

  @doc """
  Cancels all active timers associated with the LED process.

  This stops any ongoing `blink/1` or `repeat/1` patterns by clearing all stored
  `timer_refs`. Use this to reset the LED's timing behavior before issuing new
  commands.

  `name` – (optional) the GenServer name of the LED; defaults to the module.

  ## Examples

      iex> LED.cancel_timers()

      iex> LED.cancel_timers(:led_green)
  """
  @doc since: "0.1.0"
  @spec cancel_timers(GenServer.name()) :: :ok
  def cancel_timers(name \\ __MODULE__), do: GenServer.cast(name, :cancel_timers)

  # server callbacks

  @impl GenServer
  def init(init_args) do
    name = Keyword.get(init_args, :name, __MODULE__)
    gpio_pin = Keyword.get(init_args, :gpio_pin, @gpio_pin)
    initial_value = Keyword.get(init_args, :initial_value, @initial_value)

    {:ok, handle} = GPIO.open(gpio_pin, :output, initial_value: initial_value)

    {:ok, %__MODULE__{name: name, gpio_pin: gpio_pin, handle: handle, state: initial_value}}
  end

  @impl GenServer
  def handle_cast({:set, state}, %__MODULE__{} = led) do
    {:noreply, led |> struct!(state: write_gpio(led, state))}
  end

  ## timer -> blinking, repeating

  @impl GenServer
  def handle_cast({:timer_start, interval, times}, %__MODULE__{} = led) do
    timer_refs = send_timer(0, interval, times, led.timer_refs)
    state = write_gpio(led, 1)
    {:noreply, led |> struct!(timer_refs: timer_refs, state: state)}
  end

  @impl GenServer
  def handle_cast(:cancel_timers, %__MODULE__{} = led) do
    Timer.cancel(led.timer_refs)
    {:noreply, led |> struct!(timer_refs: [])}
  end

  @impl GenServer
  def handle_info({state, interval, times}, %__MODULE__{} = led) do
    timer_refs = send_timer(1 - state, interval, times, led.timer_refs)
    state = write_gpio(led, state)
    {:noreply, led |> struct!(timer_refs: timer_refs, state: state)}
  end

  defp write_gpio(led, state) do
    :ok = GPIO.write(led.handle, state)
    Logger.debug("LED #{led.name} state #{state}")
    state
  end

  defp send_timer(state, interval, times, timer_refs) do
    [Timer.send_timer({state, interval, times}) | timer_refs]
  end
end
