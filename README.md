# LED

Control one or more LEDs or relays using [Circuits.GPIO](https://hexdocs.pm/circuits_gpio/).

## Features

- Simple `on/1`, `off/1`, `set/2` API
- Supports multiple LEDs via named GenServers
- Blinking with optional interval and count

## Installation

Add to your `mix.exs`:

    def deps do
      [
        {:led, github: "yourname/led"}
      ]
    end

## Usage

### Start an LED

    {:ok, _pid} = LED.start_link(gpio_pin: 22)

### Turn it on or off

    LED.on()
    LED.off()

### set state

    LED.set(0)
    LED.set(1)

## Multiple LEDs

### Start an LED

    {:ok, _pid} = LED.start_link(name: :green_led, gpio_pin: 22, initial_value: 0)

### Turn it on or off

    LED.on(:green_led)
    LED.off(:green_led)

### set state

    LED.set(0, :green_led)

