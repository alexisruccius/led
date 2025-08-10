defmodule LED.Timer do
  @moduledoc """
  Timer helper functions for managing LED blinking and repeating patterns.

  Provides mechanisms to send timed messages for blinking intervals,
  including support for infinite repeats and countdowns.
  """
  @moduledoc since: "0.1.0"

  require Logger

  @doc """
  Schedules the next timer message for LED blinking or repeating patterns.

  - Accepts a tuple `{state, interval, times}` where:
    - `state` is `0` (off) or `1` (on).
    - `interval` is the delay in milliseconds before sending the next message.
    - `times` is the number of remaining toggles; `-1` means infinite repeats.

  - If `times` is `-1`, schedules the timer infinitely.
  - If `times` is `0`, does nothing (no timer scheduled).

  - If `state` is `0`, decrements `times` and schedules the next timer.
  - If `state` is `1`, schedules the next timer without decrementing `times`.

  Returns the timer reference or `nil` if no timer is scheduled.
  """
  @doc since: "0.1.0"
  @spec send_timer({0 | 1, integer(), integer()}) :: nil | reference()
  # -1 means infinite
  def send_timer({_state, interval, times} = message) when times <= -1 do
    send_after(message, interval)
  end

  def send_timer({_state, _interval, times}) when times == 0, do: nil

  def send_timer({0, interval, times}) do
    send_after({0, interval, times - 1}, interval)
  end

  def send_timer({1, interval, _times} = message) do
    send_after(message, interval)
  end

  defp send_after(message, interval) do
    Process.send_after(self(), message, interval)
  end

  @doc """
  Cancels a list of timer references to stop scheduled timer messages.

  - `timer_refs` is a list of references returned by `Process.send_after/3`.
  - If a `nil` timer_ref is encountered, logs a debug message and skips cancellation.
  """
  @doc since: "0.1.0"
  @spec cancel(list(reference())) :: list()
  def cancel(timer_refs), do: Enum.map(timer_refs, &cancel_ref/1)

  defp cancel_ref(timer_ref) when not is_reference(timer_ref) do
    Logger.debug("There is no timer to cancel: not is_reference(timer_ref)")
    false
  end

  defp cancel_ref(timer_ref), do: Process.cancel_timer(timer_ref)
end
