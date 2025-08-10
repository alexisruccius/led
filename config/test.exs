import Config

# for simulating a circuits GPIO device
config :circuits_gpio, default_backend: CircuitsSim.GPIO.Backend

# Circuits device simulation for a LED on gpio_pin 22 and another on 23.
config :circuits_sim,
  config: [
    {CircuitsSim.Device.GPIOLED, gpio_spec: "GPIO22"},
    {CircuitsSim.Device.GPIOLED, gpio_spec: "GPIO23"},
    {CircuitsSim.Device.GPIOLED, gpio_spec: "GPIO24"}
  ]

# Print only warnings and errors during test
config :logger, level: :warning
