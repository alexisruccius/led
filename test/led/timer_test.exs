defmodule LED.TimerTest do
  use ExUnit.Case, async: true

  alias LED.Timer

  describe "send_timer/1" do
    test "when state == 0 and times == 0 do not start a timer" do
      state = 0
      interval = 250
      timer = 0
      timer_ref = Timer.send_timer({state, interval, timer})
      assert timer_ref |> is_nil()
    end

    test "when state == 1 and times == 0 send last timer to set LED state == 0" do
      state = 1
      interval = 16
      timer = 0
      assert Timer.send_timer({state, interval, timer})
      assert_receive {0, 16, 0}
    end

    test "when times == -1 sends message without modifying for infinite loop" do
      state0 = 0
      interval = 16
      timer = -1
      assert Timer.send_timer({state0, interval, timer})
      assert_receive {0, 16, -1}, 36

      state1 = 1
      assert Timer.send_timer({state1, interval, timer})
      assert_receive {1, 16, -1}, 36
    end

    test "when times < -1 sends message without modifying for infinite loop" do
      state0 = 0
      interval = 16
      timer = -100
      assert Timer.send_timer({state0, interval, timer})
      assert_receive {0, 16, -100}, 36

      state1 = 1
      assert Timer.send_timer({state1, interval, timer})
      assert_receive {1, 16, -100}, 36
    end

    test "off message (0) sends modified message times - 1" do
      state = 0
      interval = 16
      timer = 9
      assert Timer.send_timer({state, interval, timer})
      assert_receive {0, 16, 8}, 36
    end

    test "on message (0) sends message without modifying times" do
      state = 1
      interval = 16
      timer = 6
      assert Timer.send_timer({state, interval, timer})
      assert_receive {1, 16, 6}, 36
    end
  end

  describe "cancel_/1" do
    test "cancels all timers in a list" do
      test1_ref = Process.send_after(self(), :test1, 20)
      test2_ref = Process.send_after(self(), :test2, 16)
      test3_ref = Process.send_after(self(), :test3, 0)

      assert test1_ref |> is_reference()
      assert test2_ref |> is_reference()
      assert test3_ref |> is_reference()

      timer_refs = [test1_ref, test2_ref, test3_ref]

      [a, b, c] = Timer.cancel(timer_refs)
      refute is_reference(a)
      refute is_reference(b)
      refute is_reference(c)
      assert is_integer(a) or a == false
      assert is_integer(b) or b == false
      assert is_integer(c) or c == false
    end

    test "when timer_ref is no reference return false" do
      timer_refs = [nil]
      assert [false] = Timer.cancel(timer_refs)
    end
  end
end
