from libs.core.Log import Log
from libs.TableEntryManager import TableEntryManager, TableEntry
from libs.core.Event import Event
from libs.TopologyManager import TopologyManager
from libs.Configuration import Configuration


class MacController(object):
    """
    This module implements an MacController and
    sets rewrite rules for layer 2
    """

    def __init__(self, base):
        """
        Init Maccontroller with base controller

        Args:
            base (libs.core.BaseController): Base controller
        """

        # table manager
        self.table_manager = TableEntryManager(controller=base, name="MacController")
        self.table_manager.init_table("egress.mac_c.adjust_mac")

        Event.on("topology_change", self.update)

    def update_mac_entry(self):
        """
        Add mac rewriting rule for switch->dst_dev via port

        Args:
            switch (str): switch where rule will be installed
        """
        valid_entries = []

        device = TopologyManager.get_device(Configuration.get('name'))

        for device_name in device.get_device_to_port_mapping():
            dev = TopologyManager.get_device(device_name)
            port = device.get_device_to_port(device_name)

            entry = TableEntry(match_fields={"eg_intr_md.egress_port": int(port)},
                               action_name="egress.mac_c.set_mac",
                               action_params={"srcAddr": device.get_mac(),
                                              "dstAddr": dev.get_mac()
                                              })

            TableEntryManager.handle_table_entry(manager=self.table_manager,
                                                 table_name="egress.mac_c.adjust_mac",
                                                 table_entry=entry)

            valid_entries.append(entry.match_fields)


        # remove possible old entries
        self.table_manager.remove_invalid_entries(table_name="egress.mac_c.adjust_mac", valid_entries=valid_entries)

    #############################################################
    #                   Event Listener                          #
    #############################################################

    def update(self, *args, **kwargs):
        """
        Update mac entries
        triggered by event
        """

        self.update_mac_entry()
