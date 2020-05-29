from scapy.all import *
import sys, os

TYPE_PORT_DOWN = 0xEE00

class PortDown(Packet):
    name = "PortDown"
    fields_desc = [
        BitField("pad", 0, 3),
        BitField("pipe", 0, 2),
        BitField("app_id", 0, 3),
        BitField("pad1", 0, 15),
        BitField("port_num", 0, 9),
        BitField("pkt_id", 0, 16)
    ]

bind_layers(Ether, PortDown, type=TYPE_PORT_DOWN)
