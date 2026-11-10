# Qotom Q20321G9 port map, profiled 2026-04-12 by plug-testing.
#
# 2.5G RJ45 (igc driver):
#                        Label Eth3 = enp4s0    Label Eth4 = enp5s0
#   Label Eth5 = enp8s0  Label Eth1 = enp6s0    Label Eth2 = enp7s0
#
# SFP+ right side (ixgbe driver, 10G):
#   Right-top    = eno2
#   Right-bottom = eno1
{
  eth1 = "enp6s0";
  eth2 = "enp7s0";
  eth3 = "enp4s0";
  eth4 = "enp5s0";
  eth5 = "enp8s0";
  sfpPlus1 = "eno2";
  sfpPlus2 = "eno1";
  sfpPlus3 = "eno3";
  sfpPlus4 = "eno4";
}
