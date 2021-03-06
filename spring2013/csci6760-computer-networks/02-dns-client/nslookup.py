#!/usr/bin/env python
# vim: set fileencoding=utf-8 :

from __future__ import (unicode_literals, absolute_import,
                        division, print_function)

import sys
import socket
from client.timeout import timeout, TimeoutError
from client.utils import MyParser
from client.packet import ARecordQuery, DNSAnswer
from client.dnslib.dns import QTYPE, RCODE

@timeout(5)
def receive_response(s):
    while True:
        result, ignored = s.recvfrom(1024)
        print("Response string: %s" % (result,))
        try:
            answer = DNSAnswer(result).parse()
            return answer
        except Exception:
            print("ERROR: failed to parse the answer. Illegal response"
                  + "received. Waiting for more answers...")

if __name__ == '__main__':
    if len(sys.argv) <2:
        print("Usage: %s domain_name [@dns_server]" % sys.argv[0])
        sys.exit(1)
    domain, server = MyParser(sys.argv[1:])()

    q = ARecordQuery(domain)
    message = q.pack()

    print('Query string: %s' % (message))

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(('', 10240))
    s.sendto(message, (server, 53))

    try:
        answer = receive_response(s)
        print('='*50)
        if answer.rr:
            for r in answer.rr:
                print("%-40s\t%s\t%s" % (
                    r.get_rname(),
                    QTYPE[r.rtype],
                    r.rdata))
        else:
            print("ERROR: NXDOMAIN")
            print('Reason: %s' % (RCODE[answer.header.rcode]))

    except TimeoutError:
        print("Error: timeout querying domain '%s' on server %s" % (domain,
                                                                    server))
