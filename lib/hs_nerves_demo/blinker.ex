defmodule HsNervesDemo.Blinker do
  @moduledoc """
  Reads an analog voltage from the BeagleBone ADC (AIN0, P9 pin 39) and
  blinks an LED whose frequency tracks the voltage-encoded temperature:

    * 50 °F  →  0.2 Hz  (slow blink, ~2.5 s half-period)
    * 100 °F →  10 Hz   (fast blink, 50 ms half-period)

  The relationship is linear between those extremes.

  ## Hardware wiring

  | Signal      | BeagleBone pin | Notes                          |
  |-------------|---------------|--------------------------------|
  | ADC input   | P9-39 (AIN0)  | 0 – 1.8 V max; do NOT exceed  |
  | LED anode   | P9-12 (GPIO60)| 3.3 V output; add ~220 Ω in   |
  |             |               | series to GND                  |
  | LED cathode | GND           |                                |

  ## Voltage → temperature mapping

  The full 0 – 1.8 V ADC range is mapped linearly to 50 – 100 °F
  (i.e. 0 V = 50 °F, 1.8 V = 100 °F).  Readings outside this range
  are clamped so the LED always blinks within 0.2 – 10 Hz.
  """

  use GenServer
  require Logger

  # ── Temperature / frequency constants ─────────────────────────────────
  @temp_min_f 50.0
  @temp_max_f 100.0
  @freq_min_hz 0.2
  @freq_max_hz 10.0

  # ── ADC constants ──────────────────────────────────────────────────────
  # BeagleBone Black built-in ADC: 12-bit resolution, 0 – 1.8 V
  @adc_max_raw 4095
  @adc_max_volts 1.8

  # Linux IIO sysfs path for AIN0
  @adc_sysfs_path "/sys/bus/iio/devices/iio:device0/in_voltage0_raw"

  # ── GPIO constants ─────────────────────────────────────────────────────
  # P9-12 on the BeagleBone Black expansion header = GPIO 60
  @led_gpio_pin 60

  # ── ADC polling interval ───────────────────────────────────────────────
  # Re-read the ADC twice per second so the blink rate tracks changes
  # in under 500 ms.
  @adc_poll_ms 500

  # ── Internal state ─────────────────────────────────────────────────────
  # half_period_ms is updated by :poll_adc; the :blink loop always reads it
  # from state so the rate change takes effect on the very next tick.
  defstruct [:gpio, :led_state, :half_period_ms]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    stub = Application.get_env(:hs_nerves_demo, :stub_hardware, false)

    gpio =
      if stub do
        nil
      else
        {:ok, gpio} = Circuits.GPIO.open(@led_gpio_pin, :output)
        gpio
      end

    state = %__MODULE__{
      gpio: gpio,
      led_state: 0,
      half_period_ms: freq_to_half_period(@freq_min_hz)
    }

    # Kick off the ADC polling loop (fires immediately, then every @adc_poll_ms).
    schedule_adc_poll(0)

    # Start the single, long-lived blink loop.  The :blink handler reschedules
    # itself using the current half_period_ms from state, so we never have more
    # than one outstanding :blink message at a time.
    schedule_blink(state.half_period_ms)

    {:ok, state}
  end

  # Periodic ADC poll: update the stored half_period and reschedule.
  # Does NOT start a new blink chain – it only mutates state so the
  # existing :blink loop picks up the new rate on its next iteration.
  @impl true
  def handle_info(:poll_adc, state) do
    raw = read_adc_raw()
    temp_f = adc_raw_to_temp(raw)
    freq_hz = temp_to_frequency(temp_f)
    half_ms = freq_to_half_period(freq_hz)

    Logger.debug(fn ->
      "ADC raw=#{raw}  →  #{Float.round(temp_f, 1)} °F  →  #{Float.round(freq_hz, 3)} Hz  (half-period #{half_ms} ms)"
    end)

    schedule_adc_poll(@adc_poll_ms)

    {:noreply, %{state | half_period_ms: half_ms}}
  end

  # Blink tick: toggle the LED, then schedule the *next* tick at the rate
  # currently stored in state.  Rate changes from :poll_adc take effect here.
  @impl true
  def handle_info(:blink, state) do
    new_led_state = 1 - state.led_state
    write_led(state.gpio, new_led_state)
    schedule_blink(state.half_period_ms)
    {:noreply, %{state | led_state: new_led_state}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Schedule an ADC poll message after delay_ms milliseconds.
  defp schedule_adc_poll(delay_ms) do
    Process.send_after(self(), :poll_adc, delay_ms)
  end

  # Schedule a blink tick message after half_period_ms milliseconds.
  defp schedule_blink(half_period_ms) do
    Process.send_after(self(), :blink, half_period_ms)
  end

  # Write a value (0 or 1) to the LED GPIO, or log it when stubbed.
  defp write_led(nil, value) do
    Logger.debug("LED (stub): #{value}")
  end

  defp write_led(gpio, value) do
    Circuits.GPIO.write(gpio, value)
  end

  # Read the raw 12-bit ADC value from the IIO sysfs interface.
  # Returns 0 on any error so the LED defaults to the slowest blink rate.
  defp read_adc_raw do
    case File.read(@adc_sysfs_path) do
      {:ok, data} ->
        data |> String.trim() |> String.to_integer()

      {:error, reason} ->
        Logger.warning("Could not read ADC (#{inspect(reason)}); defaulting to 0")
        0
    end
  end

  # Convert a raw 12-bit ADC reading to °F using the linear mapping
  # 0 raw (0 V) → 50 °F, @adc_max_raw (1.8 V) → 100 °F.
  defp adc_raw_to_temp(raw) do
    voltage = raw * @adc_max_volts / @adc_max_raw
    @temp_min_f + voltage / @adc_max_volts * (@temp_max_f - @temp_min_f)
  end

  # Map temperature °F to a blink frequency in Hz.
  # Values are clamped to [@temp_min_f, @temp_max_f].
  defp temp_to_frequency(temp_f) do
    t =
      temp_f
      |> max(@temp_min_f)
      |> min(@temp_max_f)
      |> Kernel.-(@temp_min_f)
      |> Kernel./(@temp_max_f - @temp_min_f)

    @freq_min_hz + t * (@freq_max_hz - @freq_min_hz)
  end

  # Convert a frequency (Hz) to the half-period (ms) used by the blink timer.
  # Half-period = 1 / (2 * freq) seconds, converted to ms.
  defp freq_to_half_period(freq_hz) do
    round(1000 / (2 * freq_hz))
  end
end
