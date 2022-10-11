p4=bfrt.l2_learn.pipe
p4_learn=bfrt.l2_learn.learn.pipe.IngressDeparser

def my_learning_cb(dev_id, pipe_id, direction, parser_id, session, msg):
    global p4

    smac=p4.Ingress.src_mac
    dmac=p4.Ingress.dst_mac

    for digest in msg:
        mac=digest["src_mac"]
        inport=digest["in_port"]
        diport=digest["port_move"]
        obport=inport^diport
        print("MAX=0x%12X Port=%d"%(max, inport), end="")
        if diport!=0:
            print("(Move from Port %d)"%obport)
        else:
            print("(New)")
        
        smac.entry_with_smac_hit(
            src_addr=mac,
            port=inport,
            entry_ttl=10000
        ).push()
        dmac.entry_with_dmac_unicast(
            dst_addr=mac,
            port=inport
        ).push()
    return 0

try:
    p4_learn.l2_digest.callback_deregister()
except:
    pass
finally:
    print("Deregistering old learning callback (if any)")
p4_learn.l2_digest.callback_register(my_learning_cb)
print("Learning callback registered")

def my_aging_cb(dev_id, pipe_id, direction, parser_id, entry):
    global p4

    smac = p4.Ingress.src_mac
    dmac = p4.Ingress.dst_mac
    
    mac = entry.key[b'hdr.ethernet.src_addr']

    print("Aging out: MAC=0x%012X"%(mac))
    
    entry.remove() # from smac
    try:
        dmac.delete(dst_addr=mac)
    except:
        print("WARNING: Could not find the matching DMAC entry")

p4.Ingress.src_mac.idle_table_set_notify(enable=False)
print("Deregistering old aging callback (if any)")

p4.Ingress.src_mac.idle_table_set_notify(enable=True, callback=my_aging_cb,
                                      interval=10000,
                                      min_ttl=10000, max_ttl=60000)
print("Aging callback registered")