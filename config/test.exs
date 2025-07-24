import Config

# for simulating a circuits GPIO device
config :circuits_gpio, default_backend: CircuitsSim.GPIO.Backend

# circuits device simulation for a LED
config :circuits_sim,
  config: [
    {CircuitsSim.Device.GPIOLED, gpio_spec: 23}
  ]
