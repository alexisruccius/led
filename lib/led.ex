defmodule LED do
  @moduledoc """
  GenServer for controlling a LED or relay.
  """

  @gpio_pin 22
  @initial_value 1

  defstruct gpio_pin: nil, output_ref: nil, state: 0
  # defstruct gpio_pin: nil, output_ref: nil, state: 0, timer_refs: [], interval: 200

  use GenServer
  alias Circuits.GPIO

  alias LED.Timer

  def start_link(init_args \\ []) do
    name = Keyword.get(init_args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_args, name: name)
  end

  @doc """
  Turns LED on.
  """
  def on(), do: set(1)

  @doc """
  Turns LED off.
  """
  def off(), do: set(0)

  @doc """
  Sets blinking to 2 Hz (250ms interval).
  """
  defdelegate blinking, to: Timer

  @doc """
  Sets blinking to interval in ms.
  """
  defdelegate blinking(interval_ms), to: Timer

  @doc """
  Sets blinking to interval in ms and change state n times.

  After n times the LED stays off.
  """
  defdelegate blinking(interval_ms, times), to: Timer

  @doc """
  Sets LED state to `1` (on) or `0` (off).
  """
  def set(state) do
    GenServer.cast(__MODULE__, {:set, state})
  end

  # server callbacks

  @impl true
  def init(init_args) do
    gpio_pin = Keyword.get(init_args, :gpio_pin, @gpio_pin)
    {:ok, output_ref} = GPIO.open(gpio_pin, :output, initial_value: @initial_value)
    {:ok, %__MODULE__{gpio_pin: gpio_pin, output_ref: output_ref, state: @initial_value}}
  end

  @impl true
  def handle_cast({:set, state}, %__MODULE__{} = led) do
    :ok = GPIO.write(led.output_ref, state)
    {:noreply, led |> struct!(state: state)}
  end
end
