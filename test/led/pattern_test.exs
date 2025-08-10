defmodule LED.PatternTest do
  use ExUnit.Case, async: true, group: :pattern_tests

  alias LED.Pattern

  doctest LED.Pattern

  describe "start_link/1" do
    test "starts GenServer" do
      {:ok, pid} = Pattern.start_link(led_name: :led_not_in_other_tests)
      assert %Pattern{} = :sys.get_state(Pattern)
      assert :ok = GenServer.stop(pid)
    end

    test "sets GenServer name" do
      {:ok, pid} = Pattern.start_link(name: :my_pattern)

      assert %Pattern{} = :sys.get_state(:my_pattern)
      assert :ok = GenServer.stop(pid)
    end

    test "sets default LED GenServer name" do
      start_link_supervised!({Pattern, led_name: :red_led})
      assert %Pattern{led_name: :red_led} = :sys.get_state(Pattern)
    end

    test "sets args into state" do
      start_link_supervised!(
        {Pattern,
         name: :my_pattern,
         led_name: :green_led,
         intervals: [10, 20, 30],
         durations: [30, 20, 10],
         overlapping?: true}
      )

      assert %Pattern{
               led_name: :green_led,
               intervals: [10, 20, 30],
               durations: [30, 20, 10],
               overlapping?: true,
               programm: %{intervals: [10, 20, 30], durations: [30, 20, 10]}
             } = :sys.get_state(:my_pattern)
    end

    test "handle empty lists set for intervals and durations, and uses defaults" do
      start_link_supervised!({Pattern, intervals: [], durations: []})

      assert %Pattern{
               intervals: [100, 25],
               durations: [500, 250, 500],
               programm: %{intervals: [100, 25], durations: [500, 250, 500]}
             } = :sys.get_state(Pattern)
    end
  end

  describe "reset/0" do
    test "resets the intervals and durations from the programm map" do
      start_link_supervised!({Pattern, intervals: [5, 6, 7], durations: [10, 20]})

      # wait for 2 triggers
      Process.sleep(23)
      assert :ok = Pattern.reset()
      assert %Pattern{intervals: [5, 6, 7], durations: [10, 20]} = :sys.get_state(Pattern)
    end

    test "stops all timer_refs in the LED GenServer and sets LED state to off (0)" do
      start_link_supervised!({LED, name: :reset_led})
      start_link_supervised!({Pattern, led_name: :reset_led, intervals: [250]})
      # wait for trigger
      Process.sleep(7)
      assert :ok = Pattern.reset()
      # wait for LED
      Process.sleep(2)
      assert %LED{state: 0, timer_refs: []} = :sys.get_state(:reset_led)
    end
  end

  describe "reset/1" do
    test "resets works for other Pattern (GenServer) name" do
      start_link_supervised!(
        {Pattern,
         name: :reset_pattern,
         led_name: :led_not_in_other_tests,
         intervals: [5, 6, 7],
         durations: [10, 20]}
      )

      # wait for 2 triggers
      Process.sleep(23)
      assert :ok = Pattern.reset(:reset_pattern)
      assert %Pattern{intervals: [5, 6, 7], durations: [10, 20]} = :sys.get_state(:reset_pattern)
    end
  end

  describe "pause/0" do
    test "trigger_ref in module struct" do
      start_link_supervised!({Pattern, intervals: [10], durations: [100]})

      # wait for trigger
      Process.sleep(16)
      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_reference()
    end

    test "handles empty trigger_ref == nil" do
      start_link_supervised!({Pattern, intervals: [10], durations: [100]})

      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_nil()
      assert :ok = Pattern.pause()
      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_nil()
    end

    test "pauses blinking without terminating the pattern process" do
      start_link_supervised!({Pattern, intervals: [5, 6, 7], durations: [10, 20]})

      # wait for 1 triggers
      Process.sleep(16)
      assert :ok = Pattern.pause()
      assert pattern1 = :sys.get_state(Pattern)
      # should not change after 10ms
      Process.sleep(10)
      assert pattern2 = :sys.get_state(Pattern)
      assert pattern1 == pattern2
    end

    test "sets LED off (0)" do
      start_link_supervised!({LED, name: :pause_led})
      start_link_supervised!({Pattern, led_name: :pause_led, intervals: [250]})
      # wait for trigger
      Process.sleep(7)
      assert :ok = Pattern.pause()
      # wait for LED
      Process.sleep(2)
      assert %LED{state: 0, timer_refs: []} = :sys.get_state(:pause_led)
    end
  end

  describe "pause/1" do
    test "pause works for other Pattern (GenServer) name" do
      start_link_supervised!(
        {Pattern,
         name: :pause_pattern,
         led_name: :led_not_in_other_tests,
         intervals: [5, 6, 7],
         durations: [10, 20]}
      )

      # wait for 1 triggers
      Process.sleep(16)
      assert :ok = Pattern.pause(:pause_pattern)
      assert pattern1 = :sys.get_state(:pause_pattern)
      # should not change after 10ms
      Process.sleep(10)
      assert pattern2 = :sys.get_state(:pause_pattern)
      assert pattern1 == pattern2
    end
  end

  describe "play/0" do
    test "resumes the blinking pattern" do
      start_link_supervised!({Pattern, intervals: [5, 10, 7], durations: [100]})

      # wait for 1 triggers
      Process.sleep(12)
      assert :ok = Pattern.pause()
      assert pattern1 = :sys.get_state(Pattern)
      # check pause after 10ms
      Process.sleep(10)
      assert pattern2 = :sys.get_state(Pattern)
      assert pattern1 == pattern2
      assert :ok = Pattern.play()
      # wait for trigger
      Process.sleep(10)
      assert pattern3 = :sys.get_state(Pattern)
      assert pattern1 != pattern3
    end
  end

  describe "handle_info/2" do
    test "triggers LED.blink" do
      start_link_supervised!({LED, name: :pattern_test_led})

      start_link_supervised!(
        {Pattern, led_name: :pattern_test_led, intervals: [10], durations: [100]}
      )

      # wait 6ms for first :trigger message
      Process.sleep(6)
      assert %LED{state: 1} = :sys.get_state(:pattern_test_led)
      Process.sleep(12)
      assert %LED{state: 0} = :sys.get_state(:pattern_test_led)
    end

    test "handles overlapping? == true" do
      start_link_supervised!({Pattern, overlapping?: true})
      # wait more than 6ms for first :trigger message
      Process.sleep(10)
      assert %Pattern{overlapping?: true} = :sys.get_state(Pattern)
    end

    test "handles false overlapping? type" do
      start_link_supervised!({Pattern, overlapping?: "not_boolean"})
      # wait more than 6ms for first :trigger message
      Process.sleep(10)
      assert %Pattern{overlapping?: false} = :sys.get_state(Pattern)
    end
  end
end
