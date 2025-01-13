#
# note: string.split() works in jinja2, so this isn't actually needed (and
# right now it's only splitting on space, not other whitespace), but it serves
# as good documentation on how to make a filter
#
class FilterModule(object):
    def filters(self):
        return {'split': string_split}

def string_split(string, sep="\x20"):
    return string.split(sep)
