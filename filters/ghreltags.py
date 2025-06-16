#!/usr/bin/env python3
#
# ghreltags filter
#  - takes a dictionary as input
#      - keys are github reponames
#      - values are full tagnames if contain any digits
#          - else are tag prefixes if non empty
#              - if empty, get defaulted from filter arg2
#  - prefixes get dereferenced via github to highest such tag by version sort
#  - returns modified dictionary with all values as exact tags after lookups
#
# args:
#  1: github username (required)
#  2: default prefix for empty keys (required)
#  3: api key / personal access token (optional) for github lookup
#
# scott@smemsh.net
# https://github.com/smemsh/setup/
# https://spdx.org/licenses/Apache-2.0 (getlinks() function only)
# https://spdx.org/licenses/GPL-2.0 (rest of file)
#

import urllib.request as rq
import json
import re
#import sys

from ansible.errors import AnsibleFilterError
from ansible.module_utils.compat.version import LooseVersion
# todo: offer StrictVersion as an option?

GHAPIBASE = 'https://api.github.com/repos'
GHAPIVER = '2022-11-28'
headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': GHAPIVER,
}

class FilterModule(object):

    def filters(self):
        return {'ghreltags': self.ghreltags}

    def ghreltags(self, repodict, ghuser, prefix, apikey=None):

        if apikey is not None:
            headers.update({'Authorization': f"Bearer {apikey}"})

        for project, peg in repodict.items():

            exact = False
            if peg == '' or peg is None:
                peg = prefix
            if not isinstance(peg, str):
                raise AnsibleFilterError('only accepts string value pegs')
            if any(c.isdigit() for c in peg):
                exact = True  # todo: use regex, with user override

            url = f"{GHAPIBASE}/{ghuser}/{project}/tags"
            url += '?per_page=100'  # default 30, max 100
            jsdata = []
            while True:
                apireq = rq.Request(url)
                #print(f"apiurl: {url}", file=sys.stderr)
                #sys.stderr.flush
                for k, v in headers.items():
                    apireq.add_header(k, v)
                with rq.urlopen(apireq) as rs:
                    links = self.getlinks(rs.headers.get('link', ''))
                    encoding = rs.headers.get('charset', 'utf-8')
                    rsdata = rs.read().decode(encoding)
                jsdata += json.loads(rsdata)
                nextp = [u.get('url') for u in links if u.get('rel') == 'next']
                if nextp: url = nextp[0]
                else: break

            alltags = [t['name'] for t in jsdata]
            pfxtags = filter(lambda x: x == peg if exact
                             else x.startswith(peg), alltags)
            try:
                tag = sorted(pfxtags, key=LooseVersion)[-1]
            except IndexError:
                raise AnsibleFilterError('no tag matches')

            repodict.update({project: tag})

        return repodict

    # snarfed from pypi requests library's utils.parse_header_links()
    # license of this function: apache-2.0
    @staticmethod
    def getlinks(value):
        links = []
        replace_chars = "\x20'\""
        value = value.strip(replace_chars)
        if not value:
            return links
        for val in re.split(",\x20*<", value):
            try: url, params = val.split(';', 1)
            except ValueError: url, params = val, ''
            link = {'url': url.strip('<> \'"')}
            for param in params.split(';'):
                try: key, value = param.split('=')
                except ValueError: break
                link[key.strip(replace_chars)] = value.strip(replace_chars)
            links.append(link)
        return links
