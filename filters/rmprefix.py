#
# note: python3.9+ has a removeprefix method for str type on its own
#

class FilterModule(object):
    def filters(self):
        return {'rmprefix': string_rmprefix}

def string_rmprefix(string, prefix):
    if string.startswith(prefix):
        return string[len(prefix):]
    return string
