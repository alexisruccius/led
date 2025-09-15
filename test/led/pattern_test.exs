defmodule LED.PatternTest do
  use ExUnit.Case, async: true, group: :led_tests

  alias LED.Pattern

  doctest LED.Pattern

  describe "start_link/1" do
    test "starts GenServer" do
      {:ok, pid_led} = LED.start_link(name: :pink_led)
      {:ok, pid_pattern} = Pattern.start_link(led_name: :pink_led)
      assert %Pattern{} = :sys.get_state(Pattern)
      assert :ok = GenServer.stop(pid_led)
      assert :ok = GenServer.stop(pid_pattern)
    end

    test "sets GenServer name" do
      start_link_supervised!(LED)
      {:ok, pid} = Pattern.start_link(name: :my_pattern)
      assert %Pattern{} = :sys.get_state(:my_pattern)
      assert :ok = GenServer.stop(pid)
    end

    test "sets default LED GenServer name" do
      start_link_supervised!({LED, name: :red_led})
      start_link_supervised!({Pattern, led_name: :red_led})
      assert %Pattern{led_name: :red_led} = :sys.get_state(Pattern)
    end

    test "sets args into state" do
      start_link_supervised!({LED, name: :green_led})

      start_link_supervised!(
        {Pattern,
         name: :my_pattern,
         led_name: :green_led,
         intervals: [10, 20, 30],
         durations: [30, 20, 10],
         overlapping?: true,
         resets: [2000, 1000]}
      )

      # first interval, duration, and reset_point is used immediately
      assert %Pattern{
               led_name: :green_led,
               intervals: [20, 30],
               durations: [20, 10],
               overlapping?: true,
               resets: [1000],
               program: %{intervals: [10, 20, 30], durations: [30, 20, 10]}
             } = :sys.get_state(:my_pattern)
    end

    test "handle empty lists set for intervals and durations, and uses defaults" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [], durations: []})

      # first interval, duration are used immediately after init
      assert %Pattern{
               intervals: [25],
               durations: [250, 500],
               program: %{intervals: [100, 25], durations: [500, 250, 500]}
             } = :sys.get_state(Pattern)
    end

    test "returns error when no LED process with :led_name" do
      assert {:error, :no_led_process} = Pattern.start_link(led_name: :led_module_not_started)
    end
  end

  describe "reset/0" do
    test "resets the intervals and durations from the program map" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [5, 6, 7], durations: [10, 20]})

      # first interval, duration are used immediately after init
      assert %Pattern{intervals: [6, 7], durations: [20]} = :sys.get_state(Pattern)
      assert :ok = Pattern.reset()
      assert %Pattern{intervals: [5, 6, 7], durations: [10, 20]} = :sys.get_state(Pattern)
    end

    test "stops all timer_refs in the LED GenServer and sets LED state to off (0)" do
      start_link_supervised!({LED, name: :reset_led})
      start_link_supervised!({Pattern, led_name: :reset_led, durations: [9], intervals: [250]})

      # first :trigger and timer_ref immediately after init
      assert %LED{timer_refs: [timer_ref | _rest]} = :sys.get_state(:reset_led)
      assert timer_ref |> is_reference()
      assert :ok = Pattern.reset()
      # wait for LED
      Process.sleep(1)
      assert %LED{state: 0, timer_refs: []} = :sys.get_state(:reset_led)
    end
  end

  describe "reset/1" do
    test "resets works for other Pattern (GenServer) name" do
      start_link_supervised!(LED)

      start_link_supervised!(
        {Pattern, name: :reset_pattern, intervals: [5, 6, 7], durations: [10, 20]}
      )

      # first interval, duration are used immediately after init
      assert %Pattern{intervals: [6, 7], durations: [20]} = :sys.get_state(:reset_pattern)
      assert :ok = Pattern.reset(:reset_pattern)
      assert %Pattern{intervals: [5, 6, 7], durations: [10, 20]} = :sys.get_state(:reset_pattern)
    end
  end

  describe "pause/0" do
    test "trigger_ref in module struct" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [10], durations: [100]})

      # first :trigger immediately after init
      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_reference()
    end

    test "handles empty trigger_ref == nil" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [10], durations: [100]})

      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      refute trigger_ref |> is_nil()
      assert :ok = Pattern.pause()
      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_nil()
      assert :ok = Pattern.pause()
      assert %Pattern{trigger_ref: trigger_ref} = :sys.get_state(Pattern)
      assert trigger_ref |> is_nil()
    end

    test "pauses blinking without terminating the pattern process" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [2, 3, 4], durations: [4, 20]})

      # first interval, duration are used immediately after init
      assert %Pattern{intervals: [3, 4], durations: [20]} = :sys.get_state(Pattern)
      assert :ok = Pattern.pause()
      assert pattern1 = :sys.get_state(Pattern)
      # should not change after 6ms
      Process.sleep(6)
      assert pattern2 = :sys.get_state(Pattern)
      assert pattern1 == pattern2
    end

    test "sets LED off (0)" do
      start_link_supervised!({LED, name: :pause_led})
      start_link_supervised!({Pattern, led_name: :pause_led, intervals: [250]})

      # first interval sets LED ON immediately after init
      assert %Pattern{intervals: []} = :sys.get_state(Pattern)
      assert %LED{state: 1} = :sys.get_state(:pause_led)
      assert :ok = Pattern.pause()
      # wait for LED
      Process.sleep(2)
      assert %LED{state: 0, timer_refs: []} = :sys.get_state(:pause_led)
    end
  end

  describe "pause/1" do
    test "pause works for other Pattern (GenServer) name" do
      start_link_supervised!(LED)

      start_link_supervised!(
        {Pattern, name: :pause_pattern, intervals: [2, 3, 4], durations: [4, 20]}
      )

      # first interval, duration are used immediately after init
      assert %Pattern{intervals: [3, 4], durations: [20]} = :sys.get_state(:pause_pattern)
      assert :ok = Pattern.pause(:pause_pattern)
      assert pattern1 = :sys.get_state(:pause_pattern)
      # should not change after 6ms
      Process.sleep(6)
      assert pattern2 = :sys.get_state(:pause_pattern)
      assert pattern1 == pattern2
    end
  end

  describe "play/0" do
    test "resumes the blinking pattern" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [5, 10, 7], durations: [100]})

      # wait for 1 trigger (duration)
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

    test "does not send :trigger when there is a trigger_ref (pattern is playing)" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [5], durations: [30]})

      # wait for 1 trigger (duration)
      Process.sleep(12)
      assert %Pattern{trigger_ref: trigger_ref1} = :sys.get_state(Pattern)
      assert trigger_ref1 |> is_reference()
      assert :ok = Pattern.play()
      Process.sleep(2)
      assert %Pattern{trigger_ref: trigger_ref2} = :sys.get_state(Pattern)
      assert trigger_ref2 |> is_reference()
      # no new trigger_ref from a play :trigger
      assert trigger_ref1 == trigger_ref2
    end
  end

  describe "change/1" do
    test "changes led_name of the pattern" do
      start_link_supervised!({LED, name: :red_led})
      start_link_supervised!({Pattern, led_name: :red_led})

      assert %{led_name: :red_led} = :sys.get_state(Pattern)
      Pattern.change(led_name: :green_led)
      assert %{led_name: :green_led} = :sys.get_state(Pattern)
    end

    test "changes the intervals of the pattern" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [10, 20], durations: [100]})

      # first interval used immediately after init
      assert %{intervals: [20]} = :sys.get_state(Pattern)
      Pattern.change(intervals: [6])
      assert %{intervals: [6]} = :sys.get_state(Pattern)
      assert %{program: %{intervals: [6]}} = :sys.get_state(Pattern)
    end

    test "preserves the intervals correctly if NOT changed" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, intervals: [5, 15, 35]})

      # first interval used immediately after init
      assert %{intervals: [15, 35]} = :sys.get_state(Pattern)
      Pattern.change(overlapping?: true)
      assert %{intervals: [15, 35]} = :sys.get_state(Pattern)
      assert %{program: %{intervals: [5, 15, 35]}} = :sys.get_state(Pattern)
    end

    test "changes the durations of the pattern" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, durations: [10, 20]})

      # first interval used immediately after init
      assert %{durations: [20]} = :sys.get_state(Pattern)
      Pattern.change(durations: [6])
      assert %{durations: [6]} = :sys.get_state(Pattern)
      assert %{program: %{durations: [6]}} = :sys.get_state(Pattern)
    end

    test "preserves the durations correctly if NOT changed" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, durations: [10, 20, 30]})

      # first interval used immediately after init
      assert %{durations: [20, 30]} = :sys.get_state(Pattern)
      Pattern.change(overlapping?: true)
      assert %{durations: [20, 30]} = :sys.get_state(Pattern)
      assert %{program: %{durations: [10, 20, 30]}} = :sys.get_state(Pattern)
    end

    test "changes overlapping? of the pattern" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, overlapping?: false})

      assert %{overlapping?: false} = :sys.get_state(Pattern)
      Pattern.change(overlapping?: true)
      assert %{overlapping?: true} = :sys.get_state(Pattern)
    end

    test "changes the resets of the pattern" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, resets: [100, 200]})

      assert %{resets: [200]} = :sys.get_state(Pattern)
      Pattern.change(resets: [69, 269])
      assert %{resets: [69, 269]} = :sys.get_state(Pattern)
    end

    test "does NOT change resets to nil if resets are not given as an opt" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, resets: [100, 200]})

      assert %{resets: [200]} = :sys.get_state(Pattern)
      Pattern.change(overlapping?: true)
      assert %{resets: [200]} = :sys.get_state(Pattern)
      assert %{program: %{resets: [100, 200]}} = :sys.get_state(Pattern)
    end

    test "if resets are changed from nil to something, initial :reset message is processed" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, resets: nil})

      assert %{resets: nil} = :sys.get_state(Pattern)
      Pattern.change(resets: [69, 269])
      assert %{resets: [269]} = :sys.get_state(Pattern)
    end

    test "if resets are changed to nil, it stays nil" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, resets: [5, 10]})

      assert %{resets: [10]} = :sys.get_state(Pattern)
      Pattern.change(resets: nil)
      assert %{resets: nil} = :sys.get_state(Pattern)
    end
  end

  describe "handle_info/2" do
    test "triggers LED.blink" do
      start_link_supervised!({LED, name: :pattern_test_led})

      start_link_supervised!(
        {Pattern, led_name: :pattern_test_led, intervals: [6], durations: [100]}
      )

      # should be triggerd on initially
      assert %LED{state: 1} = :sys.get_state(:pattern_test_led)
      # wait for 2 trigger (interval)
      Process.sleep(7)
      assert %LED{state: 0} = :sys.get_state(:pattern_test_led)
    end

    test "handles overlapping? == true" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, overlapping?: true})

      # wait for 1 trigger (duration)
      Process.sleep(12)
      assert %Pattern{overlapping?: true} = :sys.get_state(Pattern)
    end

    test "handles false overlapping? type" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, overlapping?: "not_boolean"})

      # wait for 1 trigger (duration)
      Process.sleep(10)
      assert %Pattern{overlapping?: false} = :sys.get_state(Pattern)
    end

    test "handles :resets list" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, resets: [10, 30]})

      # first reset timer should be send in init
      assert %Pattern{resets: [30]} = :sys.get_state(Pattern)
    end

    test ":resets reset durations" do
      start_link_supervised!(LED)
      start_link_supervised!({Pattern, durations: [6, 7, 8], resets: [3, 30]})

      # first duration and reset_point should be used immediately
      assert %Pattern{durations: [7, 8], resets: [30]} = :sys.get_state(Pattern)
      # wait for first reset
      Process.sleep(4)
      assert %Pattern{durations: [6, 7, 8], resets: []} = :sys.get_state(Pattern)
    end
  end
end
