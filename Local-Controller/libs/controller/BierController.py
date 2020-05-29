from libs.core.Log import Log
from libs.TableEntryManager import TableEntryManager, TableEntry
from libs.core.Event import Event
from libs.TopologyManager import TopologyManager
from libs.Configuration import Configuration


class BierController(object):
    """
    This module implements an MacController and
    sets rewrite rules for layer 2
    """

    def __init__(self, base):
        """
        Init BierController with base controller

        Args:
            base (libs.core.BaseController): Base controller
        """

        # table manager
        self.table_manager = TableEntryManager(controller=base, name="BierController")
        self.table_manager.init_table("ingress.reset_clone")

	entry = TableEntry(match_fields={"hdr.bier_md.bs": 0},
                                  action_name="ingress.nop")

	TableEntryManager.handle_table_entry(manager=self.table_manager,
                                             table_name="ingress.reset_clone",
                                             table_entry=entry)
