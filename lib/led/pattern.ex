defmodule LED.Pattern do
  @moduledoc """
  Repeating and changing LED blink patterns.

  This GenServer sends varying `blink/1` commands to an LED process
  (usually named `LED`) using changing intervals and durations.

  Patterns can overlap and loop, allowing for experimental or noise-based
  light effects.

  ## Example

  Start a pattern with default timings:

      iex> {:ok, _pid} = LED.Pattern.start_link()

  Start with custom intervals and durations:

      iex> {:ok, _pid} = LED.Pattern.start_link(
      ...> led_name: :my_led,
      ...> intervals: [100, 50, 200],
      ...> durations: [500, 800]
      ...> )
  """
  @doc since: "0.2.0"

  use GenServer

  @type t() :: %__MODULE__{
          led_name: GenServer.name(),
          intervals: list(pos_integer()),
          durations: list(pos_integer()),
          overlapping?: boolean(),
          reset_points: list(pos_integer()),
          programm: map()
        }
  defstruct led_name: LED,
            intervals: [],
            durations: [],
            overlapping?: false,
            reset_points: nil,
            programm: %{},
            trigger_ref: nil

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  @doc """
  Starts the LED.Pattern GenServer.

  ## Options

    * `:name` – assigns a custom name to the `LED.Pattern` GenServer.
       Useful for running multiple independent patterns, either on the same LED or across different LEDs.
    * `:led_name` – LED GenServer to control (defaults to `LED`)
    * `:intervals` – list of blink intervals in ms (defaults to [100, 25])
    * `:durations` – list of durations in ms after which a new blink interval is selected (defaults to `[500, 250, 500]`)
    * `:overlapping?` – if `true`, pattern timers overlap for polyrhythmic or experimental effects (defaults to `false` -> normal blinking)
    * `:reset_points` – list of times in ms when the pattern sequence resets.
      If `nil` (default), the pattern runs continuously without resets.


  ## Examples

      iex> {:ok, _pid} = LED.Pattern.start_link()

      iex> {:ok, _pid} = LED.Pattern.start_link(
      ...> led_name: :red_led,
      ...> intervals: [169, 69],
      ...> durations: [600, 900]
      ...> )

      iex> LED.Pattern.start_link(
      ...> name: :green_sparkle,
      ...> led_name: :green_led,
      ...> intervals: [100, 200],
      ...> changes: [300, 400],
      ...> overlapping?: true
      ...> )

      iex> LED.Pattern.start_link(
      ...> name: :green_beat,
      ...> led_name: :green_led,
      ...> intervals: [20, 40, 80],
      ...> changes: [150],
      ...> overlapping?: true
      ...> )

  ...>
  """
  @doc since: "0.2.0"
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args \\ []) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Pauses the currently running pattern without resetting its state.

  The pattern can be resumed later using `play/1`.

  > #### Note {: .tip}
  > This does not preserve overlapping patterns in the LED module
  > when `:overlapping?` is set to `true`.

  ## Examples

      iex> LED.Pattern.pause(:green_led_pattern)
      :ok
  """
  @spec pause(GenServer.server()) :: :ok
  def pause(name \\ __MODULE__) do
    GenServer.cast(name, :pause)
  end

  @doc """
  Resumes the currently paused pattern without resetting its state.

  The pattern can be paused using `pause/1`.

  > #### Note {: .tip}
  > This does not restart overlapping patterns in the LED module
  > when `:overlapping?` is set to `true`, because those were canceled by `pause/1`.

  ## Examples

      iex> LED.Pattern.play(:green_led_pattern)
      :ok
  """
  @spec play(GenServer.server()) :: :ok
  def play(name \\ __MODULE__) do
    GenServer.cast(name, :play)
  end

  @doc """
  Resets the current pattern to its initial state.

  Does not stop the pattern; use `pause/1` to stop it
  before calling `reset/1`.

  ## Examples

      iex> LED.Pattern.reset(:green_led_pattern)
      :ok
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(name \\ __MODULE__) do
    GenServer.cast(name, :reset)
  end

  @doc """
  Updates the running pattern with new options.

  You can dynamically change the blink `:intervals`, adjust `:durations`,
  switch the target `:led_name`, or toggle `:overlapping?` for stacking
  multiple patterns without cancellation.

  ## Example

     iex> LED.Pattern.change(:my_pattern,
     ...> intervals: [100, 200, 300],
     ...> durations: [500, 750],
     ...> led_name: :blue_led,
     ...> overlapping?: true,
     ...> reset_points: [1500, 2000]
     ...> )
  """
  @spec change(GenServer.server(), keyword()) :: :ok
  def change(name \\ __MODULE__, opts) do
    GenServer.cast(name, {:change, opts})
  end

  # callbacks

  @impl GenServer
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(args) do
    led_name = Keyword.get(args, :led_name, LED)
    intervals = args |> Keyword.get(:intervals) |> if_empty(default_intervals())
    durations = args |> Keyword.get(:durations) |> if_empty(default_durations())
    overlapping? = args |> Keyword.get(:overlapping?) |> if_not_boolean(false)
    reset_points = args |> Keyword.get(:reset_points)

    pattern = pattern(led_name, intervals, durations, overlapping?, reset_points)
    send(self(), :trigger)
    {:ok, pattern |> send_reset_point()}
  end

  @impl GenServer
  @spec handle_cast(:pause, t()) :: {:noreply, t()}
  def handle_cast(:pause, %__MODULE__{} = pattern) do
    cancel_trigger(pattern.trigger_ref)
    LED.off(pattern.led_name)
    {:noreply, pattern |> struct!(trigger_ref: nil)}
  end

  @impl GenServer
  @spec handle_cast(:play, t()) :: {:noreply, t()}
  def handle_cast(:play, %__MODULE__{} = pattern) do
    if pattern.trigger_ref |> is_nil(), do: send(self(), :trigger)
    {:noreply, pattern}
  end

  @impl GenServer
  @spec handle_cast(:reset, t()) :: {:noreply, t()}
  def handle_cast(:reset, %__MODULE__{} = pattern) do
    %__MODULE__{led_name: led_name, programm: programm} = pattern
    LED.off(led_name)
    {:noreply, pattern |> struct!(intervals: programm.intervals, durations: programm.durations)}
  end

  @impl GenServer
  @spec handle_cast({:change, keyword()}, t()) :: {:noreply, t()}
  def handle_cast({:change, opts}, %__MODULE__{} = pattern) do
    led_name = Keyword.get(opts, :led_name, pattern.led_name)
    intervals = Keyword.get(opts, :intervals, pattern.programm.intervals)
    durations = Keyword.get(opts, :durations, pattern.programm.durations)
    overlapping? = Keyword.get(opts, :overlapping?, pattern.overlapping?)
    reset_points = Keyword.get(opts, :reset_points, pattern.reset_points)

    changed_pattern = pattern(led_name, intervals, durations, overlapping?, reset_points)

    {:noreply, changed_pattern}
  end

  @impl GenServer
  @spec handle_info(:trigger, t()) :: {:noreply, t()}
  def handle_info(:trigger, %__MODULE__{} = pattern) do
    %__MODULE__{
      intervals: intervals,
      durations: durations,
      led_name: led_name,
      overlapping?: overlapping?,
      programm: programm
    } =
      pattern

    [interval_ms | intervals_rest] = if_empty(intervals, programm.intervals)
    [duration_ms | durations_rest] = if_empty(durations, programm.durations)

    trigger_led(overlapping?, interval: interval_ms, name: led_name)

    trigger_ref = Process.send_after(self(), :trigger, duration_ms)

    {:noreply,
     pattern
     |> struct!(intervals: intervals_rest, durations: durations_rest, trigger_ref: trigger_ref)}
  end

  @impl GenServer
  @spec handle_info(:reset, t()) :: {:noreply, t()}
  def handle_info(:reset, %__MODULE__{} = pattern) do
    %__MODULE__{led_name: led_name, programm: programm} = pattern
    LED.off(led_name)

    new_pattern =
      pattern
      |> struct!(intervals: programm.intervals, durations: programm.durations)
      |> send_reset_point()

    {:noreply, new_pattern}
  end

  defp if_empty(nil, default), do: default
  defp if_empty([], default_or_programm), do: default_or_programm
  defp if_empty(list, _default_or_programm), do: list

  defp if_not_boolean(term, value) when not is_boolean(term), do: value
  defp if_not_boolean(term, _value), do: term

  defp trigger_led(false = _overlapping?, opts), do: LED.blink(opts)
  defp trigger_led(true = _overlapping?, opts), do: LED.repeat(opts)

  defp default_intervals, do: [100, 25]
  defp default_durations, do: [500, 250, 500]

  defp cancel_trigger(trigger_ref) when not is_reference(trigger_ref), do: false
  defp cancel_trigger(trigger_ref), do: Process.cancel_timer(trigger_ref)

  defp pattern(led_name, intervals, durations, overlapping?, reset_points) do
    %__MODULE__{
      led_name: led_name,
      intervals: intervals,
      durations: durations,
      overlapping?: overlapping?,
      reset_points: reset_points,
      programm: %{intervals: intervals, durations: durations, reset_points: reset_points}
    }
  end

  defp send_reset_point(%__MODULE__{reset_points: reset_points} = pattern)
       when is_nil(reset_points) do
    pattern
  end

  defp send_reset_point(%__MODULE__{} = pattern) do
    [reset_ms | reset_points_rest] = if_empty(pattern.reset_points, pattern.programm.reset_points)
    Process.send_after(self(), :reset, reset_ms)
    pattern |> struct!(reset_points: reset_points_rest)
  end
end
