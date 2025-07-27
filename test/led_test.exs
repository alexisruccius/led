defmodule LEDTest do
  use ExUnit.Case

  doctest LED

  alias LED.Timer

  setup_all do
    # note: GPIO is simulated via CircuitsSim on gpio_pin 23, cf. config/test.exs
    start_supervised!({LED, gpio_pin: 22})
    :ok
  end

  describe "start_link/1" do
    test "sets GenServer name" do
      start_supervised!({LED, name: :second_led})
      assert %LED{} = :sys.get_state(:second_led)
    end

    test "sets gpio_pin" do
      start_supervised!({LED, gpio_pin: 23, name: :led_gpio_pin_test})
      assert %LED{gpio_pin: 23} = :sys.get_state(:led_gpio_pin_test)
    end

    test "sets inital_value of LED state" do
      start_supervised!({LED, name: :third_led, initial_value: 0})
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

  describe "set/2" do
    test "sets gpio led pin to 0 with custom GenServer name" do
      start_link_supervised!({LED, name: :led_green})
      LED.set(1, :led_green)
      LED.set(0, :led_green)
      assert %LED{state: 0} = :sys.get_state(:led_green)
    end
  end

  describe "on/0" do
    test "sets gpio led pin to 1" do
      LED.on()
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "on/1" do
    test "sets gpio led pin to 1 with custom GenServer name" do
      start_link_supervised!({LED, name: :led_red})
      LED.set(0, :led_red)
      LED.on(:led_red)
      assert %LED{state: 1} = :sys.get_state(:led_red)
    end
  end

  describe "off/0" do
    test "sets gpio led pin to 0" do
      LED.off()
      assert %LED{state: 0} = :sys.get_state(LED)
    end
  end

  describe "off/1" do
    test "sets gpio led pin to 0 with custom GenServer name" do
      start_link_supervised!({LED, name: :led_blue})
      LED.set(1, :led_blue)
      LED.off(:led_blue)
      assert %LED{state: 0} = :sys.get_state(:led_blue)
    end
  end

  describe "is_lit?/0" do
    test "returns true if LED state is 1 (on)" do
      LED.set(1)
      assert LED.is_lit?()
    end

    test "returns false if LED state is 0 (off)" do
      LED.set(0)
      refute LED.is_lit?()
    end
  end

  describe "is_lit?/1" do
    test "returns true if LED state is 1 (on)" do
      start_link_supervised!({LED, name: :led_pink})
      LED.set(1, :led_pink)
      assert LED.is_lit?(:led_pink)
    end

    test "returns false if LED state is 0 (off)" do
      start_link_supervised!({LED, name: :led_pink})
      LED.set(0, :led_pink)
      refute LED.is_lit?(:led_pink)
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
