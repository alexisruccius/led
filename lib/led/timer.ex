defmodule LED.Timer do
  @moduledoc """
  Starts a timer.
  """
  use GenServer

  defstruct timer_ref: nil

  def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

  def blinking() do
    cancel()
    start(250)
  end

  def blinking(interval_ms) when is_integer(interval_ms) do
    cancel()
    start(interval_ms)
  end

  def blinking(interval_ms, times) when is_integer(interval_ms) and is_integer(times) do
    cancel()
    start(interval_ms, times)
  end

  def start(interval_ms), do: GenServer.cast(__MODULE__, {:start, interval_ms})

  def start(interval_ms, times),
    do: GenServer.cast(__MODULE__, {:start, interval_ms, times})

  def cancel(), do: GenServer.cast(__MODULE__, :cancel)

  # server callbacks

  @impl true
  def init(_init_arg), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_cast({:start, interval_ms}, %__MODULE__{} = timer) do
    LED.on()
    {:noreply, timer |> struct!(timer_ref: send_timer({:off, interval_ms}))}
  end

  def handle_cast({:start, interval_ms, times}, %__MODULE__{} = timer) do
    LED.on()
    {:noreply, timer |> struct!(timer_ref: send_timer({:off, interval_ms, times}))}
  end

  @impl true
  def handle_cast(:cancel, %__MODULE__{} = timer) do
    cancel(timer.timer_ref)
    {:noreply, timer |> struct!(timer_ref: nil)}
  end

  @impl true
  def handle_info({:off, interval_ms}, %__MODULE__{} = timer) do
    LED.off()
    {:noreply, timer |> struct!(timer_ref: send_timer({:on, interval_ms}))}
  end

  @impl true
  def handle_info({:on, interval_ms}, %__MODULE__{} = timer) do
    LED.on()
    {:noreply, timer |> struct!(timer_ref: send_timer({:off, interval_ms}))}
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

  defp send_timer({_, interval_ms} = message) do
    Process.send_after(self(), message, interval_ms)
  end

  defp send_timer({_, _, times}) when times == 0, do: nil

  defp send_timer({:off, interval_ms, times}) do
    Process.send_after(self(), {:off, interval_ms, times - 1}, interval_ms)
  end

  defp send_timer({:on, interval_ms, _times} = message) do
    Process.send_after(self(), message, interval_ms)
  end

  defp cancel(timer_ref) when timer_ref == nil, do: IO.puts("no timer to cancel")
  defp cancel(timer_ref), do: Process.cancel_timer(timer_ref)
end
