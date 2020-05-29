control Port(inout header_t hdr, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_metadata_t ig_md, inout ingress_intrinsic_metadata_for_tm_t ig_tm_md, inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    Register<bit<1>, PortId_t>(2069, 0) port_status_reg;
    RegisterAction<bit<1>, PortId_t, bit<1>>(port_status_reg) port_down = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            read_value = 0;
            value = 0;
        }
    };

    RegisterAction<bit<1>, PortId_t, bit<1>>(port_status_reg) set_port_up = {
        void apply(inout bit<1> value, out bit<1> read_value) {
	    read_value = 1;
            value = 1;
        }
    };

    RegisterAction<bit<1>, PortId_t, bit<1>>(port_status_reg) port_read = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            read_value = value;
            value = value;
        }
    };

    apply {
        if(ig_md.port_event == 0) {
          @stage(4) {
           port_down.execute(hdr.port_down.port_num);
          }
        }
        else if(ig_md.port_event == 1) {
          set_port_up.execute((PortId_t) hdr.topology.port);
        }
        else if(ig_md.port_event == 2) {
            ig_md.port_status = port_read.execute(ig_tm_md.ucast_egress_port);
        }
    }
}
