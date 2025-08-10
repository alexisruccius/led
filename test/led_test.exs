defmodule LEDTest do
  use ExUnit.Case, async: true, group: :led_tests

  doctest LED

  # note: GPIO is simulated via CircuitsSim, cf. config/test.exs

  describe "start_link/1" do
    test "sets GenServer name" do
      start_supervised!({LED, name: :second_led})
      assert %LED{} = :sys.get_state(:second_led)
    end

    test "sets gpio_pin" do
      start_supervised!({LED, gpio_pin: "GPIO23", name: :led_gpio_pin_test})
      assert %LED{gpio_pin: "GPIO23"} = :sys.get_state(:led_gpio_pin_test)
    end

    test "sets inital_value of LED state" do
      start_supervised!({LED, name: :third_led, initial_value: 0})
      assert %LED{state: 0} = :sys.get_state(:third_led)
    end
  end

  describe "set/1" do
    test "sets gpio led pin to 1" do
      start_supervised!(LED)
      LED.set(1)
      assert %LED{state: 1} = :sys.get_state(LED)
    end

    test "sets gpio led pin to 0" do
      start_supervised!(LED)
      LED.set(0)
      assert %LED{state: 0} = :sys.get_state(LED)
    end

    test "handle invalid state != 0, 1" do
      start_supervised!(LED)
      assert %LED{state: initial_state} = :sys.get_state(LED)

      LED.set(0.1)
      assert %LED{state: state1} = :sys.get_state(LED)
      assert initial_state == state1
      LED.set(10)
      assert %LED{state: state2} = :sys.get_state(LED)
      assert initial_state == state2
      LED.set(-10)
      assert %LED{state: state3} = :sys.get_state(LED)
      assert initial_state == state3
    end
  end

  describe "set/2" do
    test "sets gpio led pin to 0 with custom GenServer name" do
      start_link_supervised!({LED, name: :led_green})
      LED.set(1, :led_green)
      LED.set(0, :led_green)
      assert %LED{state: 0} = :sys.get_state(:led_green)
    end

    test "timer_refs get canceled when set" do
      {:ok, _pid} = LED.start_link(name: :test_set, gpio_pin: "GPIO23", initial_value: 0)

      LED.blink(name: :test_set)
      assert %LED{timer_refs: timer_refs} = :sys.get_state(:test_set)
      assert timer_refs |> List.first() |> is_reference()

      LED.set(1, :test_set)
      assert %LED{timer_refs: timer_refs} = :sys.get_state(:test_set)
      refute timer_refs |> List.first() |> is_reference()
    end
  end

  describe "on/0" do
    test "sets gpio led pin to 1" do
      start_supervised!(LED)
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
      start_supervised!(LED)
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

  describe "lit?/0" do
    test "returns true if LED state is 1 (on)" do
      start_supervised!(LED)
      LED.set(1)
      assert LED.lit?()
    end

    test "returns false if LED state is 0 (off)" do
      start_supervised!(LED)
      LED.set(0)
      refute LED.lit?()
    end
  end

  describe "lit?/1" do
    test "returns true if LED state is 1 (on)" do
      start_link_supervised!({LED, name: :led_pink})
      LED.set(1, :led_pink)
      assert LED.lit?(:led_pink)
    end

    test "returns false if LED state is 0 (off)" do
      start_link_supervised!({LED, name: :led_pink})
      LED.set(0, :led_pink)
      refute LED.lit?(:led_pink)
    end
  end

  describe "toggle/1" do
    test "toggles LED state on and off" do
      {:ok, _pid} = LED.start_link(name: :test_toggle, gpio_pin: "GPIO23", initial_value: 0)

      assert LED.lit?(:test_toggle) == false

      LED.toggle(:test_toggle)
      assert LED.lit?(:test_toggle) == true

      LED.toggle(:test_toggle)
      assert LED.lit?(:test_toggle) == false
    end

    test "timer_refs get canceled whenn toggling" do
      {:ok, _pid} = LED.start_link(name: :test_toggle, gpio_pin: "GPIO23", initial_value: 0)

      LED.blink(name: :test_toggle)
      assert %LED{timer_refs: timer_refs} = :sys.get_state(:test_toggle)
      assert timer_refs |> List.first() |> is_reference()

      LED.toggle(:test_toggle)
      assert %LED{timer_refs: timer_refs} = :sys.get_state(:test_toggle)
      refute timer_refs |> List.first() |> is_reference()
    end
  end

  describe "blink/0" do
    test "sets gpio led to blinking at 2 Hz" do
      start_supervised!(LED)

      # 2 Hz is a interval of 250ms
      LED.blink()
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(260)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(250)
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "blink/2" do
    test "sets gpio led to blinking at 100ms" do
      pid = start_link_supervised!({LED, gpio_pin: "GPIO24", name: :timer_test1})
      assert pid |> is_pid()

      LED.blink(name: :timer_test1, interval: 100)
      :timer.sleep(20)
      assert %LED{state: 1} = :sys.get_state(:timer_test1)
      :timer.sleep(100)
      assert %LED{state: 0} = :sys.get_state(:timer_test1)
      :timer.sleep(100)
      assert %LED{state: 1} = :sys.get_state(:timer_test1)
    end

    test "sets gpio led to blinking at 100ms for 2 times" do
      pid = start_link_supervised!({LED, gpio_pin: "GPIO23", name: :timer_test3})
      assert pid |> is_pid()

      LED.blink(name: :timer_test3, interval: 50, times: 2)
      :timer.sleep(10)
      assert %LED{state: 1} = :sys.get_state(:timer_test3)
      :timer.sleep(50)
      assert %LED{state: 0} = :sys.get_state(:timer_test3)
      :timer.sleep(50)
      assert %LED{state: 1} = :sys.get_state(:timer_test3)
      :timer.sleep(100)
      assert %LED{state: 0} = :sys.get_state(:timer_test3)
    end
  end

  describe "repeat/0" do
    test "sets gpio led to blinking at 2 Hz" do
      start_supervised!(LED)
      # 2 Hz is a interval of 250ms
      LED.repeat()
      assert %LED{state: 1} = :sys.get_state(LED)
      :timer.sleep(260)
      assert %LED{state: 0} = :sys.get_state(LED)
      :timer.sleep(250)
      assert %LED{state: 1} = :sys.get_state(LED)
    end
  end

  describe "repeat/2" do
    test "does not cancel old timers before starting for artful behaviour" do
      pid = start_link_supervised!({LED, gpio_pin: "GPIO24", name: :repeat_test})
      assert pid |> is_pid()

      # Pattern should be (> = trigger on/off)
      # 50ms 1 1 1 1 1 0 0 0 0 0
      #      >         >
      # 20ms 1 1 0 0 1 1 0 0 1 1
      #      >   >   >   >   >
      # ------------------------
      # =>   1 1 0 0 1 0 0 0 1 1

      LED.repeat(name: :repeat_test, interval: 50)
      LED.repeat(name: :repeat_test, interval: 20)
      assert %LED{state: 1} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 1} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 0} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 0} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 1} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 0} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 0} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 0} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 1} = :sys.get_state(:repeat_test)
      :timer.sleep(10)
      assert %LED{state: 1} = :sys.get_state(:repeat_test)
    end
  end
end
