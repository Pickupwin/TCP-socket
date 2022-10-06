p4 = bfrt.rdma_counter.pipe

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
ing_mirror_table.add_with_ing_mirror(ingress_port=184, mirror_session=5)


import os
os.environ['SDE_INSTALL'] = os.path.split(os.environ['PATH'].split(":")[0])[0]
os.environ['SDE']         = os.path.split(os.environ['SDE_INSTALL'])[0]

def run_pd_rpc(cmd_or_code, no_print=False):
    """
    This function invokes run_pd_rpc.py tool. It has a single string argument
    cmd_or_code that works as follows:
       If it is a string:
            * if the string starts with os.sep, then it is a filename
            * otherwise it is a piece of code (passed via "--eval"
       Else it is a list/tuple and it is passed "as-is"

    Note: do not attempt to run the tool in the interactive mode!
    """
    import subprocess
    path = "/home/subw/tools/run_pd_rpc.py"
    
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
run_pd_rpc("/home/subw/cfg/mirror.py")
