# hs-nerves-demo

A [Nerves](https://nerves-project.org/) demo for the **BeagleBone Black** that
blinks an LED at a rate proportional to the temperature read from an analog
sensor on the ADC input.

| Temperature | Blink frequency |
|-------------|-----------------|
| 50 °F       | 0.2 Hz  (slow)  |
| 100 °F      | 10 Hz   (fast)  |

The mapping is **linear** between those extremes.

---

## Hardware

| Signal      | BeagleBone pin | Notes                                      |
|-------------|---------------|--------------------------------------------|
| ADC input   | **P9-39** (AIN0) | Analog 0 – 1.8 V. **Do not exceed 1.8 V** |
| LED anode   | **P9-12** (GPIO 60) | 3.3 V output; add ~220 Ω resistor to GND |
| LED cathode | GND             |                                            |

Connect a temperature sensor (e.g. TMP36 or LM35) whose output spans
**0 V at 50 °F → 1.8 V at 100 °F** to P9-39.  Adjust the mapping
constants in `lib/hs_nerves_demo/blinker.ex` for your specific sensor's
voltage-to-temperature curve.

---

## Prerequisites

* [Elixir ≥ 1.14](https://elixir-lang.org/install.html)
* [Nerves Bootstrap](https://hexdocs.pm/nerves/installation.html)

```sh
mix archive.install hex nerves_bootstrap
```

---

## Building & deploying

```sh
# Set the target (BeagleBone Black)
export MIX_TARGET=bbb

# Fetch dependencies
mix deps.get

# Build the firmware image
mix firmware

# Write to a MicroSD card (replace /dev/sdX with your card device)
mix burn
```

Insert the MicroSD card into the BeagleBone Black and power it on.
The LED on P9-12 will start blinking immediately.

---

## Connecting over SSH

Once the board is on the network (DHCP on eth0), connect with:

```sh
ssh nerves.local
```

---

## How it works

1. `HsNervesDemo.Blinker` (a `GenServer`) starts at boot.
2. Every 500 ms it reads the raw 12-bit ADC value from  
   `/sys/bus/iio/devices/iio:device0/in_voltage0_raw`.
3. The raw value is converted to a voltage (0 – 1.8 V) and then to  
   temperature (50 – 100 °F) using a linear mapping.
4. The temperature is converted to a blink frequency (0.2 – 10 Hz).
5. A recurring `:blink` timer toggles GPIO 60 at the computed half-period,  
   making the LED blink at the desired rate.