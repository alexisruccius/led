import Config

# for simulating a circuits GPIO device
config :circuits_gpio, default_backend: CircuitsSim.GPIO.Backend

# Circuits device simulation for a LED on gpio_pin 22 and another on 23.
config :circuits_sim,
  config: [
    {CircuitsSim.Device.GPIOLED, gpio_spec: 22},
    {CircuitsSim.Device.GPIOLED, gpio_spec: 23}
  ]
