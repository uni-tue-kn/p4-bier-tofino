"""
This module implements an TopologyController
Sends topology packets, receives topology packets and build topology
"""

from scapy.all import *
from libs.packet_header.TopologyPacket import TopologyDiscovery
from libs.core.Log import Log
from libs.core.Event import Event
from libs.core.Host import Host
from libs.TopologyManager import TopologyManager
from libs.Configuration import Configuration
import proto.connection_pb2
import threading


class TopologyController:

    def __init__(self, controller):
        self.__baseController = controller
        Event.on("topology_packet_in", self.handle_topology_answer)

    def handle_topology_answer(self, *args, **kwargs):
        """
        Handle topology packet
        :param args: contains the topology packet
        :return:
        """
        packet = kwargs.get('packet')
        switch = kwargs.get('switch')

        pkt = packet

        pkt = packet.payload
        Event.trigger("clear_port_down", port=int(pkt.port))

        if pkt.device_type != 1:
            name = "s" + str(pkt.identifier)
            TopologyManager.add_device(name=name, device=Host(name=name, ip=pkt.ip, mac=pkt.mac))
        else:  # its a host
            name = "h" + str(pkt.identifier)
            TopologyManager.add_device(name=name, device=Host(name=name, ip=pkt.ip, mac=pkt.mac))

        if TopologyManager.get_device(name=switch).add_device_to_port(device=name, port=int(pkt.port)):
            Event.trigger("topology_change", src_device=switch, dst_device=name, port=int(pkt.port))

	#Log.info("Pkt in:", pkt.port)
        topology_packet = proto.connection_pb2.TopologyPacket(ip=pkt.ip, mac=pkt.mac, port=pkt.port, name=name, switch=Configuration.get('name'))

        Event.trigger("topology_to_controller", pkt=topology_packet)
