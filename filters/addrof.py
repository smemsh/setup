#

from socket import gethostbyname, herror
from ansible.errors import AnsibleFilterError

class FilterModule(object):

    def filters(self):
        return {'addrof': self.addrof}

    def addrof(self, host):
        try: addr = gethostbyname(host)
        except herror: raise AnsibleFilterError(f"{host}: lookup failed")
        return addr
