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
  require Logger

  @type t() :: %__MODULE__{
          led_name: GenServer.name(),
          intervals: list(pos_integer()),
          durations: list(pos_integer()),
          overlapping?: boolean(),
          resets: list(pos_integer()),
          program: map()
        }
  defstruct led_name: LED,
            intervals: [100, 25],
            durations: [500, 250, 500],
            overlapping?: false,
            resets: nil,
            program: %{},
            trigger_ref: nil

  @type options :: [
          {:name, atom()},
          {:led_name, GenServer.name()},
          {:intervals, [pos_integer()]},
          {:durations, [pos_integer()]},
          {:overlapping?, boolean()},
          {:resets, [pos_integer()]}
        ]

  @doc """
  Starts the LED.Pattern GenServer.


  ## Options

    * `:name` – assigns a custom name to the `LED.Pattern` GenServer.
       Useful for running multiple independent patterns, either on the same LED or across different LEDs.
    * `:led_name` – LED GenServer to control (defaults to `LED`)
    * `:intervals` – list of blink intervals in ms (defaults to [100, 25])
    * `:durations` – list of durations in ms after which a new blink interval is selected (defaults to `[500, 250, 500]`)
    * `:overlapping?` – if `true`, pattern timers overlap for polyrhythmic or experimental effects (defaults to `false` -> normal blinking)
    * `:resets` – list of times in ms when the pattern sequence resets.
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
      ...> durations: [300, 400],
      ...> overlapping?: true
      ...> )

      iex> LED.Pattern.start_link(
      ...> name: :green_beat,
      ...> led_name: :green_led,
      ...> intervals: [20, 40, 80],
      ...> durations: [150],
      ...> overlapping?: true
      ...> )

  ...>
  """
  @doc since: "0.2.0"
  @spec start_link(options()) :: GenServer.on_start()
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
     ...> resets: [1500, 2000]
     ...> )
  """
  @spec change(GenServer.server(), options()) :: :ok
  def change(name \\ __MODULE__, opts) do
    GenServer.cast(name, {:change, opts})
  end

  # callbacks

  @impl GenServer
  @spec init(options()) :: {:ok, t()}
  def init(args) do
    pattern = build_pattern(args)
    send(self(), :trigger)
    {:ok, pattern |> send_reset()}
  end

  @impl GenServer
  @spec handle_cast(:pause, t()) :: {:noreply, t()}
  def handle_cast(:pause, %__MODULE__{} = pattern) do
    cancel_trigger(pattern.trigger_ref)
    LED.off(pattern.led_name)
    {:noreply, %{pattern | trigger_ref: nil}}
  end

  @impl GenServer
  @spec handle_cast(:play, t()) :: {:noreply, t()}
  def handle_cast(:play, %__MODULE__{} = pattern) do
    if pattern.trigger_ref |> is_nil(), do: send(self(), :trigger)
    {:noreply, pattern}
  end

  @impl GenServer
  @spec handle_cast({:change, options()}, t()) :: {:noreply, t()}
  def handle_cast({:change, opts}, %__MODULE__{} = pattern) do
    defaults = pattern |> reset_to_program()
    changed_pattern = build_pattern(opts, defaults)
    {:noreply, changed_pattern}
  end

  @impl GenServer
  @spec handle_cast(:reset, t()) :: {:noreply, t()}
  def handle_cast(:reset, %__MODULE__{} = pattern) do
    LED.off(pattern.led_name)
    {:noreply, pattern |> reset_to_program()}
  end

  # handle_info

  @impl GenServer
  @spec handle_info(:reset, t()) :: {:noreply, t()}
  def handle_info(:reset, %__MODULE__{} = pattern) do
    LED.off(pattern.led_name)
    {:noreply, pattern |> reset_to_program() |> send_reset()}
  end

  @impl GenServer
  @spec handle_info(:trigger, t()) :: {:noreply, t()}
  def handle_info(:trigger, %__MODULE__{} = pattern) do
    [interval_ms | intervals_rest] = pattern.intervals |> fallback(pattern.program.intervals)
    [duration_ms | durations_rest] = pattern.durations |> fallback(pattern.program.durations)

    opts = [interval: interval_ms, name: pattern.led_name]

    if pattern.overlapping?, do: LED.repeat(opts), else: LED.blink(opts)

    trigger_ref = Process.send_after(self(), :trigger, duration_ms)

    {:noreply,
     %{pattern | intervals: intervals_rest, durations: durations_rest, trigger_ref: trigger_ref}}
  end

  # private funs

  defp build_pattern(opts, defaults \\ %__MODULE__{}) do
    led_name = Keyword.get(opts, :led_name, defaults.led_name)
    intervals = opts |> Keyword.get(:intervals) |> fallback(defaults.intervals)
    durations = opts |> Keyword.get(:durations) |> fallback(defaults.durations)
    overlapping? = opts |> Keyword.get(:overlapping?, false) |> if_not_boolean(false)
    resets = opts |> Keyword.get(:resets)

    %__MODULE__{
      led_name: led_name,
      intervals: intervals,
      durations: durations,
      overlapping?: overlapping?,
      resets: resets,
      program: %{intervals: intervals, durations: durations, resets: resets}
    }
  end

  defp fallback(nil, default), do: default
  defp fallback([], default_or_program), do: default_or_program
  defp fallback(list, _default_or_program), do: list

  defp reset_to_program(%__MODULE__{} = pattern) do
    %{pattern | intervals: pattern.program.intervals, durations: pattern.program.durations}
  end

  defp if_not_boolean(term, value) when not is_boolean(term) do
    Logger.warning("\"#{term}\" for :overlapping? is not a boolean, false is used as default.")
    value
  end

  defp if_not_boolean(term, _value), do: term

  defp cancel_trigger(trigger_ref) when not is_reference(trigger_ref), do: false
  defp cancel_trigger(trigger_ref), do: Process.cancel_timer(trigger_ref)

  defp send_reset(%__MODULE__{resets: resets} = pattern) when is_nil(resets), do: pattern

  defp send_reset(%__MODULE__{} = pattern) do
    [reset_ms | resets_rest] = fallback(pattern.resets, pattern.program.resets)
    Process.send_after(self(), :reset, reset_ms)
    %{pattern | resets: resets_rest}
  end
end
