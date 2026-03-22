import Config

# On the host we cannot access real hardware, so the blinker uses stub
# paths that will return a "no hardware" default (0 raw ADC) rather
# than crashing.  Set :stub_hardware to true so the Blinker module
# knows to skip GPIO initialisation.
config :hs_nerves_demo, stub_hardware: true
