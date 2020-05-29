"""
This module manages the native IPMC multicast groups on the P4 switch
"""
import sys

sys.path.append('/opt/bf-sde-8.9.1/install/lib/python2.7/site-packages')
from libs.core.Event import Event
from libs.core.Log import Log
from libs.TopologyManager import TopologyManager
from libs.TableEntryManager import TableEntryManager, TableEntry
from libs.Configuration import Configuration
from libs.Exceptions import DeviceNotFound
import subprocess
from subprocess import Popen, PIPE, STDOUT
from collections import defaultdict
from libs.PD import set_port_map, set_lag_map
from ptf.thriftutils import *

class MulticastController(object):

    def __init__(self, pd=None, base=None):
        self.mcgrp_to_port = defaultdict(list)
        self.mcgrp_to_gid = defaultdict(int)
        self.mcgrp_to_nid = defaultdict(int)
        self.mcgrp_to_id = defaultdict(int)
        self.pd = pd
        Event.on("igmp_packet_to_controller", self.update_igmp)

        self.table_manager = TableEntryManager(controller=base, name="GroupController")
        self.table_manager.init_table("ingress.ip_c.ipv4_mc")

    def update_mc_group(self, mc_addr=None, ports=None):

        if mc_addr in self.mcgrp_to_id:
            g_id = self.mcgrp_to_id[mc_addr]
        else:
            g_id = max(self.mcgrp_to_id.values()) + 1 if len(self.mcgrp_to_id.values()) > 0 else 2
            self.mcgrp_to_id[mc_addr] = g_id

        ################################################################################
        # destory old mc grp
        ################################################################################
        if mc_addr in self.mcgrp_to_gid:
            self.pd.mc.mc.mc_mgrp_destroy(self.pd.mc.mc_sess_hdl, 0, self.mcgrp_to_gid[mc_addr])

        ################################################################################
        # create new mc grp
        ################################################################################
        gid = self.pd.mc.mc.mc_mgrp_create(self.pd.mc.mc_sess_hdl, 0, g_id)
        self.mcgrp_to_gid[mc_addr] = gid

        ################################################################################
        # destroy node associated with ports
        ################################################################################
        if mc_addr in self.mcgrp_to_nid:
            self.pd.mc.mc.mc_node_destroy(self.pd.mc.mc_sess_hdl, 0, self.mcgrp_to_nid[mc_addr])

        ################################################################################
        # create node associated with ports
        ################################################################################
        nid = self.pd.mc.mc.mc_node_create(self.pd.mc.mc_sess_hdl, 0, g_id, set_port_map(ports), set_lag_map([]))
        self.mcgrp_to_nid[mc_addr] = nid

        ################################################################################
        # associate node and grp
        ################################################################################
        self.pd.mc.mc.mc_associate_node(self.pd.mc.mc_sess_hdl, 0, gid, nid, 0, 0)


    def update_igmp(self, pkt):
        """
        Update port information on ipmc groups
        """
        switch = TopologyManager.get_device(name=Configuration.get('name'))
        mc_addr = pkt.mc_address.encode('utf-8')
        src_ip = pkt.src_ip.encode('utf-8')


        try:
            port = switch.get_device_to_port(TopologyManager.get_device_by_ip(ip=src_ip).get_name())
        except DeviceNotFound:
            return
        if pkt.type == 0x16:
            if port not in self.mcgrp_to_port[mc_addr]:
                self.mcgrp_to_port[mc_addr].append(port)
        elif pkt.type == 0x17:
            if port in self.mcgrp_to_port[mc_addr]:
                self.mcgrp_to_port[mc_addr].remove(port)

        self.update_mc_table()


    def update_mc_table(self):
        valid_entries = []

        for mcgrp in self.mcgrp_to_port:
            if self.mcgrp_to_port[mcgrp]:
                self.update_mc_group(mc_addr=mcgrp, ports=self.mcgrp_to_port[mcgrp])

                entry = TableEntry(match_fields={"hdr.ipv4.dst_addr": mcgrp},
                                   action_name="ingress.ip_c.native_mc",
                                   action_params={"mgrp_id": self.mcgrp_to_id[mcgrp] })



                TableEntryManager.handle_table_entry(manager=self.table_manager,
                                                     table_name="ingress.ip_c.ipv4_mc",
                                                     table_entry=entry)

                valid_entries.append(entry.match_fields)
        self.table_manager.remove_invalid_entries(table_name="ingress.ip_c.ipv4_mc", valid_entries=valid_entries)
