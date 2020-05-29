import sys
sys.path.append('/opt/bf-sde-8.9.1/install/lib/python2.7/site-packages/tofino')
sys.path.append('/opt/bf-sde-8.9.1/install/lib/python2.7/site-packages')


import importlib
import struct
import threading
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol, TMultiplexedProtocol

from scapy.all import *
from libs.packet_header.TopologyPacket import TopologyDiscovery
from ptf.thriftutils import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from conn_mgr_pd_rpc.ttypes import *
from libs.Configuration import Configuration
from libs.core.Log import Log
from libs.core.Event import Event
from libs.TopologyManager import TopologyManager

from libs.packet_header.PortDown import PortDown


def set_port_map(indices):
    bit_map = [0] * ((288+7)/8)
    for i in indices:
        index = portToBitIdx(i)
        bit_map[index/8] = (bit_map[index/8] | (1 << (index%8))) & 0xFF

    return bytes_to_string(bit_map)

def portToBitIdx(port):
    pipe = port >> 7
    index = port & 0x7F

    return 72 * pipe + index

def set_lag_map(indices):
    bit_map = [0] * ((256 * 7)/8)

    for i in indices:
        bit_map[i/8] = (bit_map[i/8] | (1 << (i%8))) & 0xFF

    return bytes_to_string(bit_map)

def port_down_packet():
    # we need at least 58 bytes
    pkt = Ether(src='00:00:00:00:00:00', dst='ff:ff:ff:ff:ff:ff', type=0xEE00) / IP() / IP() / IP()
    return pkt

def mirror_session(mir_type, mir_dir, sid, egr_port=0, egr_port_v=False,
                   egr_port_queue=0, packet_color=0, mcast_grp_a=0,
                   mcast_grp_a_v=False, mcast_grp_b=0, mcast_grp_b_v=False,
                   max_pkt_len=0, level1_mcast_hash=0, level2_mcast_hash=0,
                   mcast_l1_xid=0, mcast_l2_xid=0, mcast_rid=0, cos=0, c2c=False, extract_len=0, timeout=0,
                   int_hdr=[], hdr_len=0):
  return MirrorSessionInfo_t(mir_type,
                             mir_dir,
                             sid,
                             egr_port,
                             egr_port_v,
                             egr_port_queue,
                             packet_color,
                             mcast_grp_a,
                             mcast_grp_a_v,
                             mcast_grp_b,
                             mcast_grp_b_v,
                             max_pkt_len,
                             level1_mcast_hash,
                             level2_mcast_hash,
                             mcast_l1_xid,
                             mcast_l2_xid,
                             mcast_rid,
                             cos,
                             c2c,
                             extract_len,
                             timeout,
                             int_hdr,
                             hdr_len)

class ThriftConnection:
    def __init__(self):
        self.transport = TTransport.TBufferedTransport(TSocket.TSocket("localhost", 9090))
        self.protocol = TBinaryProtocol.TBinaryProtocol(self.transport)
        self.conn_mgr_client_module = importlib.import_module(".".join(["conn_mgr_pd_rpc", "conn_mgr"]))
        self.conn_mgr_protocol = self.conn_mgr_protocol = TMultiplexedProtocol.TMultiplexedProtocol(self.protocol, "conn_mgr")
        self.conn_mgr = self.conn_mgr_client_module.Client(self.conn_mgr_protocol)

        self.transport.open()

        self.hdl = self.conn_mgr.client_init()

    def end(self):
        self.conn_mgr.client_cleanup(self.hdl)

class PortConfig():


    def __init__(self, thrift_con=None):
        self.pal_protocol = TMultiplexedProtocol.TMultiplexedProtocol(thrift_con.protocol, "pal")
        self.pal_client_module = importlib.import_module(".".join(["pal_rpc", "pal"]))
        self.pal = self.pal_client_module.Client(self.pal_protocol)


    def setPorts(self, data=None):
        for configuration in data[Configuration.get('name')]:
            p_id = self.pal.pal_port_front_panel_port_to_dev_port_get(0, configuration['port'], configuration['channel'])
            self.pal.pal_port_add(0, p_id, configuration['speed'], pal_fec_type_t.BF_FEC_TYP_NONE)
            self.pal.pal_port_an_set(0, p_id, 2)
            self.pal.pal_port_enable(0, p_id)
            
            if 'loopback' in configuration and configuration['loopback']:
                self.pal.pal_port_loopback_mode_set(0, p_id, 1)
                Log.debug("Set port", p_id, "to loopback")


class MirrorConfig():
    def __init__(self, thrift_con=None, pal=None):
        self.thrift_con = thrift_con
        self.mirror_protocol = TMultiplexedProtocol.TMultiplexedProtocol(thrift_con.protocol, "mirror")
        self.mirror_client_module = importlib.import_module(".".join(["mirror_pd_rpc", "mirror"]))
        self.mirror = self.mirror_client_module.Client(self.mirror_protocol)
        self.pal = pal

    def get_mirror_port(self, data=None):
        mirror_ports = []

        for configuration in data[Configuration.get('name')]:
            if 'mirror' in configuration and configuration['mirror']:
                m_port = self.pal.pal_port_front_panel_port_to_dev_port_get(0, configuration['port'], configuration['channel'])
                mirror_ports.append(m_port)

        return mirror_ports

    def setMirrorSession(self, data=None):
        ports = self.get_mirror_port(data)

        if ports is None:
            return

        for i, p in enumerate(ports):
            dt = DevTarget_t(0, hex_to_i16(0xFFFF))
            session = 1000 + i
            info = mirror_session(MirrorType_e.PD_MIRROR_TYPE_NORM,
                                  Direction_e.PD_DIR_INGRESS,
                                  session,
                                  p,
                                  True)

            self.mirror.mirror_session_create(self.thrift_con.hdl, dt, info)
            self.thrift_con.conn_mgr.complete_operations(self.thrift_con.hdl)

            self.mirror.mirror_session_enable(self.thrift_con.hdl, Direction_e.PD_DIR_INGRESS, dt, 1000)
            self.thrift_con.conn_mgr.complete_operations(self.thrift_con.hdl)

            Log.debug("Create mirror session", session, "to port", p)

            self.pal.pal_port_loopback_mode_set(0, p, 1)


class McConfig():
    def __init__(self, thrift_con=None, pal=None):
        self.mc_protocol = TMultiplexedProtocol.TMultiplexedProtocol(thrift_con.protocol, "mc")
        self.mc_client_module = importlib.import_module(".".join(["mc_pd_rpc", "mc"]))
        self.mc = self.mc_client_module.Client(self.mc_protocol)
        self.mc_sess_hdl = self.mc.mc_create_session()
        self.pal = pal


    def setFlood(self, data=None):
        grp_id = self.mc.mc_mgrp_create(self.mc_sess_hdl, 0, 1)
        ports = []

        for configuration in data[Configuration.get('name')]:
            p_id = self.pal.pal_port_front_panel_port_to_dev_port_get(0, configuration['port'], configuration['channel'])

            if configuration['flood']:
                ports.append(p_id)

        node = self.mc.mc_node_create(self.mc_sess_hdl, 0, 0, set_port_map(ports), set_lag_map([]))
        self.mc.mc_associate_node(self.mc_sess_hdl, 0, grp_id, node, 0, 0)

    def end(self):
        self.mc.mc_destroy_session(self.mc_sess_hdl)


class PortMonitorConfig():
    def __init__(self, thrift_con=None, pal=None):
        self.pal = pal
        self.tc = thrift_con
        self.port_pkt_len = 0
        Event.on("clear_port_down", self.clear_port)

    def configureTopologyPackets(self):
        """
        Configure topology packet trigger
        """

        timeout = 10 * 100 * 100 * 100 * 100 # 1 s
        dt = DevTarget_t(0, hex_to_i16(0xFFFF))

        switch = TopologyManager.get_device(Configuration.get('name'))
        pkt = Ether(src='00:00:00:00:00:00', dst='ff:ff:ff:ff:ff:ff', type=0xDD00)

        pkt = pkt / TopologyDiscovery(identifier=switch.get_bfr_id(0),
                                      port=1,
                                      ip=str(switch.get_ip()),
                                      mac=str(switch.get_mac())) / IP() / IP()

        pktlen = len(pkt)
        offset = (int(self.port_pkt_len/16) + 5) * 16
        self.tc.conn_mgr.pktgen_write_pkt_buffer(self.tc.hdl, dt, offset, pktlen, str(pkt))

        config = PktGenAppCfg_t(trigger_type=PktGenTriggerType_t.TIMER_PERIODIC,
                                timer=timeout,
                                src_port=68,
                                buffer_offset=offset,
                                length=pktlen)
        self.tc.conn_mgr.pktgen_cfg_app(self.tc.hdl, dt, 1, config)
        self.tc.conn_mgr.pktgen_app_enable(self.tc.hdl, dt, 1)

    def setupProtection(self, data=None):
        self.data = data
        Log.info("Setup port protection")
	dt = DevTarget_t(0, hex_to_i16(0xFFFF))

        p = port_down_packet()
        pktlen = self.port_pkt_len = len(p)

        self.tc.conn_mgr.pktgen_write_pkt_buffer(self.tc.hdl, dt, 0, pktlen, str(p))

	offset = 0
        # enable on all pipes

        for pipe in range(0, self.pal.pal_num_pipes_get(0)):
	    port = (pipe << 7 | 68)
            self.tc.conn_mgr.pktgen_enable(self.tc.hdl, 0, (pipe << 7 | 68))
	    Log.debug("Enable pkt gen on port", port)

        config = PktGenAppCfg_t(trigger_type=PktGenTriggerType_t.PORT_DOWN,
                                timer=0,
                                src_port=68,
                                buffer_offset=offset,
                                length=pktlen)
        self.tc.conn_mgr.pktgen_cfg_app(self.tc.hdl, dt, 0, config)
        self.tc.conn_mgr.pktgen_app_enable(self.tc.hdl, dt, 0)
        offset=pktlen


    def clear_port(self, port=None):
        self.tc.conn_mgr.pktgen_clear_port_down(self.tc.hdl, 0, port)


class PDSetup:

    def __init__(self):
        self.tc = ThriftConnection()
        self.pc = PortConfig(thrift_con=self.tc)
        self.mc = McConfig(thrift_con=self.tc, pal=self.pc.pal)
        self.mirror = MirrorConfig(thrift_con=self.tc, pal=self.pc.pal)
        self.pm = PortMonitorConfig(thrift_con=self.tc, pal=self.pc.pal)

    def setPorts(self, config_file=None):
        Log.info("Set ports")
        self.pc.setPorts(Configuration.load(config_file))

    def setFlood(self, config_file=None):
        Log.info("Set flood mc group")
        self.mc.setFlood(Configuration.load(config_file))

    def setMirrorSession(self, config_file=None):
        Log.info("Set mirror session")
        self.mirror.setMirrorSession(Configuration.load(config_file))

    def setPortMonitor(self, config_file=None):
        Log.info("Set port monitor")
        self.pm.setupProtection(Configuration.load(config_file))

    def configureTopologyPackets(self, config_file=None):
        Log.info("Configure topology packets")
        self.pm.configureTopologyPackets()

    def end(self):
        Log.info("Close pd connection")
        self.mc.end()
        self.tc.end()
