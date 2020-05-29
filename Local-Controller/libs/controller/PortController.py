from __future__ import print_function
import struct
from scapy.all import *
from libs.packet_header.PortDown import PortDown
from libs.core.Log import Log
from operator import ior
from libs.TableEntryManager import TableEntryManager, TableEntry
from libs.Configuration import Configuration
from libs.TopologyManager import TopologyManager
from libs.core.Event import Event
from collections import defaultdict
import proto.connection_pb2


class PortController:
    """
    This module monitors the port status of the switch.
    """

    def __init__(self, controller=None):
        """
        Initialize PortController with base controller and notification_socket
        :param controller: BaseController which manages SwitchConnection
        :param notification_socket: notification_socket for nanomsg
        """
        # this may be removed later when registers are used
        self.table_manager = TableEntryManager(controller=controller, name="PortController")

        self.table_manager.init_table(table_name="SwitchIngress.port_c.port_status")

        # save port status received by nanomsg message, default up
        self.port_status = defaultdict(lambda: 1)

        Event.on("port_down", self.updatePorts)
        #Event.on("topology_change", self.update)


    def updatePorts(self, pkt=None):
        port = pkt[PortDown].port_num
        device = TopologyManager.get_device(Configuration.get('name'))
        device.remove_port(port=port)
        Event.trigger("topology_change")

        Event.trigger("port_msg_to_controller", info=proto.connection_pb2.PortInfo(switch=Configuration.get('name'), port=port, status=False))



    def write_port_entry(self, port_string=None):
        entry = TableEntry(action_name="SwitchIngress.port_c.set_port_status",
                           action_params={"livePorts": port_string},
                           priority=1)

        TableEntryManager.handle_table_entry(manager=self.table_manager,
                                             table_name="SwitchIngress.port_c.port_status",
                                             table_entry=entry)

    def update(self, **kwargs):
        device = TopologyManager.get_device(Configuration.get('name'))
        live_ports = device.get_device_to_port_mapping().values()

        port_ids = map(lambda x: int(2**(x-1)), live_ports)

        # this prevents an empty sequence and forces liveport bitstring of 0
        port_ids.append(0)
        port_string = reduce(ior, port_ids)

        self.write_port_entry(port_string=port_string)
