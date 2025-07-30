# 🟢 LED 

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

## ⚙️ Connect LED to Raspberry Pi (GPIO 22) example

- Anode (long leg) → GPIO pin 22
- Cathode (short leg) → 330Ω resistor → GND

```shell
┌─────┬────────────┬─────────────────────┐
│ Pin │ Use        │ Connection          │
├─────┼────────────┼─────────────────────┤
│  6    GND          ────────────────┐   │
│ 15    GPIO22       ───▶|───[330Ω]──┘   │
└─────┴────────────┴─────────────────────┘
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

## Using with Nerves

You can integrate the `LED` module into your [Nerves](https://hexdocs.pm/nerves/getting-started.html) application's supervision tree.  
For example, to control a LED connected to GPIO pin 23 (default is 22), add the LED process like this:

```elixir
children = [
  {LED, [gpio_pin: 23]}
]
```

This ensures the LED is supervised and ready to use with functions like `LED.on/0` or `LED.blink/1`.

💡 Works great on [Nerves-supported devices](https://hexdocs.pm/nerves/supported-targets.html) like Raspberry Pi or BeagleBone.

## Disclaimer

  > #### Note on use with relay {: .tip}
  > When using a relay, check its datasheet
  > for minimum switch times to avoid damage or malfunction.

