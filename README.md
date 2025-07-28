# 🟢 LED 

Control LEDs or relays. A simple library with some artful gimmicks.

This library is a simple, convenient wrapper around [Circuits.GPIO](https://hexdocs.pm/circuits_gpio/)
for controlling LEDs or relays. Beyond basic on/off control, it enables artful, experimental,
and even random noise light effects through overlapping repeating patterns — offering creative flexibility.

## ✨ Features

- ⚡ Control single LEDs or relays on GPIO pins
- ✔ Easy on/off control
- ⏰ Blink and repeat patterns with configurable intervals and counts
- 💡 Toggle LED state
- 🎛️ Optional named LED processes for multiple devices
- Supports overlapping repeat patterns for creative effects
- Defaults to GPIO pin `22` with LED initially on

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:led, "~> 0.1.0"}
  ]
end
```

## 🛠 Usage

### Start an LED

* Default (gpio_pin: 22, initially on):

```elixir
{:ok, _pid} = LED.start_link()
```

* Named (gpio_pin: 23, initially off):

```elixir
{:ok, _pid} = LED.start_link(name: :green_led, gpio_pin: 23, initial_value: 0)
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

  > #### Note on use with relay {: .tip}
  > When using a relay, check its datasheet
  > for minimum switch times to avoid damage or malfunction.

