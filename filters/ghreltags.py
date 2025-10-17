#!/usr/bin/env python3
"""
ghreltags
  input dict of reponames and return with latest release tag as values

desc:
  - takes dict of github repos as filter input (see args spec)
  - can also run from cmdline with dict provided on stdin as json
  - tags looked up, filtered by prefix (in dict value) or provided default
  - dict returned with values replaced by highest tag via version sort
  - uses cache key arg so tags api call happens only once per repo per play
  - cache uses a lockfile for safety, but should be run only with throttle=1

args:
  1: dictionary
     - keys are github reponames
     - values are full tagnames if contain any digits
         - else are tag prefixes if non empty
             - if empty, get defaulted from filter arg2
  2: github username reponames are relative to (required) [filter arg1]
  3: default prefix for empty keys (required)             [filter arg2]
  4: cache key str, eg ansible_date_time.epoch (required) [filter arg3]
  5: api key / access token (optional) for github lookup  [filter arg4]

"""
__url__     = 'https://github.com/smemsh/setup/'
__author__  = 'Scott Mcdermott <scott@smemsh.net>'
__license__ = ['GPL-2.0', 'Apache-2.0'] # latter for getlinks() only
__devskel__ = '0.8.1'

from sys import exit, hexversion
if hexversion < 0x030900f0: exit("minpython: %s" % hexversion)

import argparse, shelve, json, re
import urllib.request as rq

from sys import argv, stdin, stdout, stderr
from copy import copy
from time import sleep
from select import select

from stat import S_IRUSR, S_IWUSR, S_IRGRP, S_IWGRP, S_IROTH
from fcntl import flock, LOCK_EX, LOCK_UN, LOCK_NB
from errno import EAGAIN, EWOULDBLOCK, EACCES

from os.path import basename, dirname
from os import (
    makedirs,
    getenv, unsetenv,
    isatty, dup,
    O_RDWR, O_CREAT,
    open as osopen,
    close as osclose,
    EX_OK as EXIT_SUCCESS,
    EX_SOFTWARE as EXIT_FAILURE,
)

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

CACHEFILE = f"{getenv('HOME')}/.cache/ghreltags.db"
CACHELOCK = f"{CACHEFILE}.lock"
LOCKSLEEP = 3
LOCKTRIES = 3

#

# we cannot use the FilterModule constructor to provision the cache and
# lock, because ansible creates a FilterModule instance for every
# defined filter in every fork (apparently, tested with a dummy),
# regardless of whether they get used by the play.  so we create our own
# class for the cache, and only instantiate if the filter gets called.
#
# note: in theory there's only one FilterModule instance per fork so we
# might have just used class variables to store the tags list and it
# would work with throttle=1, however: (1) implementing it with an
# external cache protects against accidental use with parallel forks;
# (2) we can also protect from rearchitecture or changed semantics of
# FilterModule by later ansible development; (3) we can implement an
# age-based cache later by persisting it; (4) we could pass a special
# cachekey value (like 0) to use the last stored cache contents; (5) we
# could eventually populate the shelf db through some external means
# that avoids the API altogether (as we control all the repositories
# ourselves).
#
class RelTagsCache(object):

    def __init__(self):

        # all the FilterModules are independent so we cannot share data
        # amongst instances.  we create a persistent cache and try to
        # open it for each run so the filter functions can access it.
        # the cache's purpose is to reduce API requests for tags list
        # lookups.  we delegate_to the controller but we still populate
        # the facts for each host separately (ie delegate_facts: false)
        # because each host can have different repos (although usually
        # they don't).  we store repository tag list api fetch results
        # in the cache, so really there is only one api request per repo
        # (but then also per result page) no matter how many hosts we're
        # running the play on.  (github is quite stingy with api
        # requests and even this many will be problematic unless we're
        # authenticated, which is why we take apitok parameter.)
        #
        # to implement the cache we use a python shelve object, which is
        # actually just a sqlite3 db that stores a pickled blob for the
        # value of each dictionary key that we store.  in the cache
        # object constructor, we open a protective global lock file and
        # refuse to proceed if we cannot get a lock (after some
        # sleep/retry attempts).  the lock is for safety, and we bail if
        # we can't acquire it, but this is only a guard.  the task that
        # uses this filter should (1) use it only once in the particular
        # task's template, (2) use strategy=linear if any other task
        # uses the filter, and (3) use throttle=1 on the task, so other
        # hosts will run serially and let the first one have db access
        # to [potentially] populate it.  if they were to all run at
        # once, due to the lock and retry, it would still work somewhat,
        # but it is better to serialize execution explicitly in the task
        # itself, and avoid reliance on this protection (and eventual
        # task failure if it were to wait long enough to exceed the lock
        # acquisition timeout).
        #
        makedirs(dirname(CACHELOCK), exist_ok=True)
        lockmode = S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH  # 0664
        lockfd = osopen(CACHELOCK, O_CREAT | O_RDWR, lockmode)
        tries = 0
        while True:
            try: flock(lockfd, LOCK_EX | LOCK_NB)
            except OSError as e:
                if e.errno not in [EAGAIN, EWOULDBLOCK, EACCES]:
                    bomb("unknown errno after failed flock attempt")
                tries += 1
                if (tries > LOCKTRIES):
                    bomb("exclusive cache lock failed after",
                         LOCKSLEEP * LOCKTRIES, "seconds")
                sleep(LOCKSLEEP)
                continue
            break

        self.tagshelf = shelve.open(CACHEFILE, writeback=True)
        self.lockfd = lockfd
        self.runid = ""  # filled by FilterModule.ghreltags()


    def __del__(self):

        # remove any keys from prior runs, we only cache one run
        # todo: cache for some lifetime passed as an arg?
        #
        cachekeys = self.tagshelf.keys()
        for key in cachekeys:
            if key != self.runid:
                del self.tagshelf[key]

        self.tagshelf.close()
        flock(self.lockfd, LOCK_UN)


class FilterModule(object):

    apiheaders = {'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': GHAPIVER }

    def filters(self):
        return {'ghreltags': self.ghreltags}

    def ghreltags(self, repodict, ghuser, prefix, cachekey, apikey=None):

        cache = RelTagsCache()
        cachedict = cache.tagshelf.get(cachekey) or {}
        cache.runid = cachekey  # destructor removes other keys

        headers = copy(self.apiheaders)
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

            if (alltags := cachedict.get(project)) is None:

                # not found in cache, so do the [paginated] api call
                url = f"{GHAPIBASE}/{ghuser}/{project}/tags"
                url += '?per_page=100'  # default 30, max 100
                jsdata = []
                while True:
                    apireq = rq.Request(url)
                    for k, v in headers.items():
                        apireq.add_header(k, v)
                    with rq.urlopen(apireq) as rs:
                        links = self.getlinks(rs.headers.get('link', ''))
                        encoding = rs.headers.get('charset', 'utf-8')
                        rsdata = rs.read().decode(encoding)
                    jsdata += json.loads(rsdata)
                    nextp = [u.get('url') for u in links
                             if u.get('rel') == 'next']
                    if nextp: url = nextp[0]
                    else: break

                # extract tags and add to cache so next host can bypass api
                alltags = [t['name'] for t in jsdata]
                cachedict[project] = alltags

            pfxtags = filter(lambda x: x == peg if exact
                             else x.startswith(peg), alltags)
            try:
                tag = sorted(pfxtags, key=LooseVersion)[-1]
            except IndexError:
                raise AnsibleFilterError('no tag matches')

            repodict.update({project: tag})

        # persist anything new we've learned to the shelf
        cache.tagshelf[cache.runid] = cachedict

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
    addarg  (p, 'playid', 'cache key unique to play, reduces api lookups')
    addnarg (p, 'apitok', 'github access token or api key')

    args = p.parse_args(args)


###

def ghreltags():

    if not (func := FilterModule().filters().get(invname)):
        bomb("cannot retrieve eponymous filter function from cli")

    repodict = json.load(infile)
    parms = (repodict, args.user, args.prefix)
    if (tok := args.apitok) is not None: parms += (tok,)

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
