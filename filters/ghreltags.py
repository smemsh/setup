#!/usr/bin/env python3
"""
ghreltags
  input dict of reponames and return with latest release tag as values

desc:
  - takes dict of github repos as filter input (see args spec)
  - tags looked up, filtered by prefix (in dict value) or provided default
  - dict returned with values replaced by highest tag via version sort
  - can also run from cmdline with dict provided on stdin as json

args:
  1: dictionary
     - keys are github reponames
     - values are full tagnames if contain any digits
         - else are tag prefixes if non empty
             - if empty, get defaulted from filter arg2
  2: github username reponames are relative to (required) [filter arg1]
  3: default prefix for empty keys (required)             [filter arg2]
  4: api key / access token (optional) for github lookup  [filter arg3]

"""
__url__     = 'https://github.com/smemsh/devskel/'
__author__  = 'Scott Mcdermott <scott@smemsh.net>'
__license__ = ['GPL-2.0', 'Apache-2.0'] # latter for getlinks() only
__devskel__ = '0.8.1'

from sys import exit, hexversion
if hexversion < 0x030900f0: exit("minpython: %s" % hexversion)

import urllib.request as rq
import json
import re
#import sys

from ansible.errors import AnsibleFilterError
from ansible.module_utils.compat.version import LooseVersion
# todo: offer StrictVersion as an option?

###

def err(*args, **kwargs):
    print(*args, file=stderr, **kwargs)

def bomb(*args, **kwargs):
    err(*args, **kwargs)
    exit(EXIT_FAILURE)

###

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

###

def process_args():

    global args

    def usagex(*args, **kwargs):
        nonlocal p
        p.print_help(file=stderr)
        print(file=stderr)
        bomb(*args, **kwargs)

    def addarg(p, vname, help=None, /, **kwargs):
        p.add_argument(vname, help=help, **kwargs)

    def addnarg(*args, **kwargs):
        addarg(*args, nargs='?', **kwargs)

    p = argparse.ArgumentParser(
        prog            = invname,
        description     = __doc__.strip(),
        allow_abbrev    = False,
        formatter_class = argparse.RawTextHelpFormatter,
    )
    addarg  (p, 'user', 'github username housing repositories to look up')
    addarg  (p, 'prefix', 'filter out tags not matching this prefix')
    addnarg (p, 'apitok', 'github access token or api key')

    args = p.parse_args(args)


###

def ghreltags():

    if not (func := FilterModule().filters().get(invname)):
        bomb("cannot retrieve eponymous filter function from cli")

    repodict = json.load(infile)
    parms = (repodict, args.user, args.prefix)
    if (t := args.apitok) is not None: parms += (t,)

    for k, v in func(*parms).items():
        print(f"{k}: {v}")


def main():

    if debug == 1:
        breakpoint()

    process_args()
    try: subprogram = globals()[invname]
    except (KeyError, TypeError):
        from inspect import trace
        if len(trace()) == 1: bomb("unimplemented")
        else: raise

    return subprogram()

###

if __name__ == "__main__":

    import argparse

    from sys import argv
    from sys import stdin, stdout, stderr
    from select import select

    from os.path import basename
    from os import (
        getenv, unsetenv,
        isatty, dup,
        close as osclose,
        EX_OK as EXIT_SUCCESS,
        EX_SOFTWARE as EXIT_FAILURE,
    )

    invname = basename(argv[0])
    args = argv[1:]

    # move stdin, pdb needs stdio fds itself
    stdinfd = stdin.fileno()
    if not isatty(stdinfd):
        try:
            if select([stdin], [], [])[0]:
                infile = open(dup(stdinfd))
                osclose(stdinfd)  # cpython bug 73582
                try: stdin = open('/dev/tty')
                except: pass  # no ctty, but then pdb would not be in use
        except KeyboardInterrupt:
            bomb("interrupted")
    else:
        bomb("supply json dict on stdin")

    from bdb import BdbQuit
    if debug := int(getenv('DEBUG') or 0):
        import pdb
        from pprint import pp
        err('debug: enabled')
        unsetenv('DEBUG')  # otherwise forked children hang

    try: main()
    except BdbQuit: bomb("debug: stop")
    except SystemExit: raise
    except KeyboardInterrupt: bomb("interrupted")
    except:
        from traceback import print_exc
        print_exc(file=stderr)
        if debug: pdb.post_mortem()
        else: bomb("aborting...")
    finally:  # cpython bug 55589
        try: stdout.flush()
        finally:
            try: stdout.close()
            finally:
                try: stderr.flush()
                except: pass
                finally: stderr.close()
