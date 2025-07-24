defmodule LEDTest do
  use ExUnit.Case

  alias LED.Timer

  setup_all do
    # note: GPIO is simulated via CircuitsSim on gpio_pin 23, cf. config/test.exs
    start_supervised!({LED, gpio_pin: 23})
    :ok
  end

  describe "start_link/1" do
    test "sets GenServer name" do
      start_supervised!({LED, gpio_pin: 23, name: :second_led})
      assert %LED{} = :sys.get_state(:second_led)
    end

    test "sets gpio_pin" do
      assert %LED{gpio_pin: 23} = :sys.get_state(LED)
    end

    test "sets inital_value of LED state" do
      start_supervised!({LED, gpio_pin: 23, name: :third_led, initial_value: 0})
      assert %LED{state: 0} = :sys.get_state(:third_led)
    end
  end

  describe "set/1" do
    test "sets gpio led pin to 1" do
      LED.set(1)
      assert %LED{state: 1} = :sys.get_state(LED)
    end

    test "sets gpio led pin to 0" do
      LED.set(0)
      assert %LED{state: 0} = :sys.get_state(LED)
    end
  end

  describe "on/0" do
    test "sets gpio led pin to 1" do
      LED.on()
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "off/0" do
    test "sets gpio led pin to 0" do
      LED.off()
      assert %LED{state: 0} = :sys.get_state(LED)
    end
  end

  describe "blinking/0" do
    test "sets gpio led to blinking at 2 Hz" do
      start_link_supervised!(Timer)

      # 2 Hz is a interval of 250ms
      LED.blinking()
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(260)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(250)
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "blinking/1" do
    test "sets gpio led to blinking at 100ms" do
      start_link_supervised!(Timer)

      LED.blinking(100)
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(120)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(100)
      assert %LED{state: 1} = :sys.get_state(LED)
    end

    test "cancel old timers before starting" do
      start_link_supervised!(Timer)

      LED.blinking(50)
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(60)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(50)
      assert %LED{state: 1} = :sys.get_state(LED)
      LED.blinking(200)
      # if timer is 1 after 50ms -> old timer does not trigger any more
      :timer.sleep(50)
      assert %LED{state: 1} = :sys.get_state(LED)
      # and the 200 ms blinking is still 1
      :timer.sleep(50)
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "blinking/2" do
    test "sets gpio led to blinking at 100ms for 2 times" do
      start_supervised!(Timer)

      LED.blinking(50, 2)
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(60)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(50)
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(100)
      assert %LED{state: 0} = :sys.get_state(LED)
    end
  end
end
