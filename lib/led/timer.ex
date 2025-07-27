defmodule LED.Timer do
  @moduledoc """
  Starts a timer.
  """
  use GenServer

  defstruct timer_ref: nil

  def start_link(init_arg) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  def blinking(interval_ms, times, name \\ __MODULE__)
      when is_integer(interval_ms) and is_integer(times) do
    cancel()
    start(interval_ms, times, name)
  end

  @doc """
  Start timer.

  `interval_ms`: interval in milliseconds.

  `times`: times to blink.  `-1` means infinite/continous.
  """
  def start(interval_ms, times \\ -1, name \\ __MODULE__),
    do: GenServer.cast(name, {:start, interval_ms, times})

  def cancel(name \\ __MODULE__), do: GenServer.cast(name, :cancel)

  # server callbacks

  @impl true
  def init(_init_arg), do: {:ok, %__MODULE__{}}

  def handle_cast({:start, interval_ms, times}, %__MODULE__{} = timer) do
    LED.on()
    {:noreply, timer |> struct!(timer_ref: send_timer({:off, interval_ms, times}))}
  end

  @impl true
  def handle_cast(:cancel, %__MODULE__{} = timer) do
    cancel_timer(timer.timer_ref)
    {:noreply, timer |> struct!(timer_ref: nil)}
  end

  @impl true
  def handle_info({:off, interval_ms, times}, %__MODULE__{} = timer) do
    LED.off()
    {:noreply, timer |> struct!(timer_ref: send_timer({:on, interval_ms, times}))}
  end

  def handle_info({:on, interval_ms, times}, %__MODULE__{} = timer) do
    LED.on()
    {:noreply, timer |> struct!(timer_ref: send_timer({:off, interval_ms, times}))}
  end

  # -1 means infinite
  defp send_timer({_, interval_ms, times} = message) when times == -1 do
    send_after(message, interval_ms)
  end

  defp send_timer({_, _, times}) when times == 0, do: nil

  defp send_timer({:off, interval_ms, times}) do
    send_after({:off, interval_ms, times - 1}, interval_ms)
  end

  defp send_timer({:on, interval_ms, _times} = message), do: send_after(message, interval_ms)

  defp send_after(message, interval_ms) do
    Process.send_after(self(), message, interval_ms)
  end

  defp cancel_timer(timer_ref) when timer_ref == nil, do: IO.puts("no timer to cancel")
  defp cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref)
end
