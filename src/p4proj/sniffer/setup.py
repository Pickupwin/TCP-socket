p4 = bfrt.sniffer.pipe

def clear_all():
    global p4
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR', 'SELECTOR', 'ACTION_PROFILE']:
            print("Clearing table {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
clear_all()

eth_forward=p4.Ingress.eth_forward
eth_forward.add_with_sendto(dst_addr=0xb8cef683b2ea, port=184)
eth_forward.add_with_sendto(dst_addr=0x08c0eb333174, port=188)

ing_mirror_table=p4.Ingress.ing_mirror_table
ing_mirror_table.add_with_NoAction(src_addr=0xb8cef683b2ea, dst_addr=0x08c0eb333174)
ing_mirror_table.add_with_NoAction(src_addr=0x08c0eb333174, dst_addr=0xb8cef683b2ea)

def run_pd_rpc(cmd_or_code, no_print=False):
    import subprocess
    path = "/home/subw/p4tools/run_pd_rpc.py"
    
    command = [path]
    if isinstance(cmd_or_code, str):
        if cmd_or_code.startswith(os.sep):
            command.extend(["--no-wait", cmd_or_code])
        else:
            command.extend(["--no-wait", "--eval", cmd_or_code])
    else:
        command.extend(cmd_or_code)
        
    result = subprocess.check_output(command).decode("utf-8")[:-1]
    if not no_print:
        print(result)
        
    return result

print("\nMirror Session Configuration:")
run_pd_rpc("/home/subw/p4proj/sniffer/cfg/mirror.py")
