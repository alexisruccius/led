defmodule LED.TimerTest do
  use ExUnit.Case

  alias LED.Timer

  setup_all do
    start_link_supervised!(Timer)
    :ok
  end

  describe "start/1" do
    test "timer_ref is present" do
      Timer.start(250)
      assert %Timer{timer_ref: timer_ref} = :sys.get_state(Timer)
      assert is_reference(timer_ref)
    end
  end
end
