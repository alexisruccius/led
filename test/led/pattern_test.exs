defmodule LED.PatternTest do
  use ExUnit.Case, async: true

  alias LED.Pattern

  doctest LED.Pattern

  describe "start_link/1" do
    test "starts with defaults" do
      {:ok, pid} = Pattern.start_link()
      assert %Pattern{} = :sys.get_state(Pattern)
      assert :ok = GenServer.stop(pid)
    end

    test "sets GenServer name" do
      {:ok, pid} = Pattern.start_link(name: :my_pattern)
      assert %Pattern{} = :sys.get_state(:my_pattern)
      assert :ok = GenServer.stop(pid)
    end

    test "sets default LED GenServer name" do
      start_supervised!({Pattern, led_name: :red_led})
      assert %Pattern{led_name: :red_led} = :sys.get_state(Pattern)
    end

    test "sets args into state" do
      start_supervised!(
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
      start_supervised!({Pattern, intervals: [], durations: []})

      assert %Pattern{
               intervals: [100, 25],
               durations: [500, 250, 500],
               programm: %{intervals: [100, 25], durations: [500, 250, 500]}
             } = :sys.get_state(Pattern)
    end
  end

  describe "handle_info/2" do
    test "triggers LED.blink" do
      start_supervised!(LED)
      start_supervised!({Pattern, intervals: [10], durations: [100]})
      # wait 6ms for first :trigger message
      Process.sleep(6)
      assert %LED{state: 1} = :sys.get_state(LED)
      Process.sleep(12)
      assert %LED{state: 0} = :sys.get_state(LED)
    end

    test "handles overlapping? == true" do
      start_supervised!({Pattern, overlapping?: true})
      # wait more than 6ms for first :trigger message
      Process.sleep(10)
      assert %Pattern{overlapping?: true} = :sys.get_state(Pattern)
    end

    test "handles false overlapping? type" do
      start_supervised!({Pattern, overlapping?: "not_boolean"})
      # wait more than 6ms for first :trigger message
      Process.sleep(10)
      assert %Pattern{overlapping?: false} = :sys.get_state(Pattern)
    end
  end
end
