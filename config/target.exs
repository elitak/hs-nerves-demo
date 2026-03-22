import Config

# Use the real hardware on the BeagleBone target.
config :hs_nerves_demo, stub_hardware: false

# Nerves networking – bring up eth0 via DHCP if a cable is plugged in.
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
    {"usb0", %{type: VintageNetDirect}}
  ]

# Enable SSH access (password "nerves").
config :nerves_ssh,
  authorized_keys: []
