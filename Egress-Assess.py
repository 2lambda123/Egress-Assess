#!/usr/bin/env python

# This tool is designed to be an easy way to test exfiltrating data
# from the network you are currently plugged into.  Used for red or
# blue teams that want to test network boundary egress detection
# capabilities.


import logging
import sys
from common import helpers
from common import orchestra


if __name__ == "__main__":

    logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

    helpers.title_screen()

    cli_parsed = helpers.cli_parser()

    the_conductor = orchestra.Conductor()

    # Check if only listing supported server/client protocols or datatypes
    if cli_parsed.list_servers:
        print "[*] Supported server protocols: \n"
        the_conductor.load_server_protocols(cli_parsed)
        for name, server_module in the_conductor.server_protocols.iteritems():
            print "[+] " + server_module.protocol
        print
        sys.exit()

    elif cli_parsed.list_clients:
        print "[*] Supported client protocols: \n"
        the_conductor.load_client_protocols(cli_parsed)
        for name, client_module in the_conductor.client_protocols.iteritems():
            print "[+] " + client_module.protocol
        print
        sys.exit()

    elif cli_parsed.list_datatypes:
        print "[*] Supported data types: \n"
        the_conductor.load_datatypes(cli_parsed)
        for name, datatype_module in the_conductor.datatypes.iteritems():
            print "[+] " + datatype_module.cli + " - (" +\
                datatype_module.description + ")"
        print
        sys.exit()

    if cli_parsed.server is not None:
        the_conductor.load_server_protocols(cli_parsed)

        for full_path, server in the_conductor.server_protocols.iteritems():

            if server.protocol == cli_parsed.server.lower():
                server.serve()

    elif cli_parsed.client is not None:
        # load up all supported client protocols and datatypes
        the_conductor.load_client_protocols(cli_parsed)
        the_conductor.load_datatypes(cli_parsed)

        if cli_parsed.file is None:
            # Loop through and find the requested datatype
            for name, datatype_module in the_conductor.datatypes.iteritems():
                if datatype_module.cli == cli_parsed.datatype.lower():
                    generated_data = datatype_module.generate_data()

                    # Once data has been generated, transmit it using the 
                    # protocol requested by the user
                    for proto_name, proto_module in the_conductor.client_protocols.iteritems():
                        if proto_module.protocol == cli_parsed.client.lower():
                            proto_module.transmit(generated_data)
                            sys.exit()

        else:
            with open(cli_parsed.file, 'rb') as file_data_handle:
                file_data = file_data_handle.read()

            for proto_name, proto_module in the_conductor.client_protocols.iteritems():
                if proto_module.protocol == cli_parsed.client.lower():
                    proto_module.transmit(file_data)
                    sys.exit()

        print "[*] Error: You either didn't provide a valid datatype or client protocol to use."
        print "[*] Error: Re-run and use --list-datatypes or --list-clients to see possible options."
        sys.exit()
