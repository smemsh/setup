# -*- coding: utf-8 -*-
# Copyright (c) 2023, Al Bowles <@akatch>
# Copyright (c) 2012-2014, Michael DeHaan <michael.dehaan@gmail.com>
# GNU General Public License v3.0+ (see LICENSES/GPL-3.0-or-later.txt or https://www.gnu.org/licenses/gpl-3.0.txt)
# SPDX-License-Identifier: GPL-3.0-or-later

# Make coding more python3-ish
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r"""
name: smemshy
type: stdout
author: Al Bowles (@akatch), modified by Scott Mcdermott (@smemsh)
short_description: condensed Ansible output
description:
  - Consolidated Ansible output in the style of LINUX/UNIX startup logs.
extends_documentation_fragment:
  - default_callback
requirements:
  - set as stdout in configuration
"""

from os.path import basename
from ansible import constants as C
from ansible import context
from ansible.module_utils.common.text.converters import to_text
from ansible.plugins.callback.default import CallbackModule as CallbackModule_default

### below block directly copied from lib/ansible/utils/color.py
##############################################################################

import re
import sys
ANSIBLE_COLOR = True
if C.ANSIBLE_NOCOLOR:
    ANSIBLE_COLOR = False
elif not hasattr(sys.stdout, 'isatty') or not sys.stdout.isatty():
    ANSIBLE_COLOR = False
else:
    try:
        import curses
        curses.setupterm()
        if curses.tigetnum('colors') < 0:
            ANSIBLE_COLOR = False
    except ImportError:
        # curses library was not found
        pass
    except curses.error:
        # curses returns an error (e.g. could not find terminal)
        ANSIBLE_COLOR = False

if C.ANSIBLE_FORCE_COLOR:
    ANSIBLE_COLOR = True

# --- begin "pretty"
#
# pretty - A miniature library that provides a Python print and stdout
# wrapper that makes colored terminal text easier to use (e.g. without
# having to mess around with ANSI escape sequences). This code is public
# domain - there is no license except that you must leave this header.
#
# Copyright (C) 2008 Brian Nez <thedude at bri1 dot com>


def parsecolor(color):
    """SGR parameter string for the specified color name."""
    matches = re.match(r"color(?P<color>[0-9]+)"
                       r"|(?P<rgb>rgb(?P<red>[0-5])(?P<green>[0-5])(?P<blue>[0-5]))"
                       r"|gray(?P<gray>[0-9]+)", color)
    if not matches:
        return C.COLOR_CODES[color]
    if matches.group('color'):
        return u'38;5;%d' % int(matches.group('color'))
    if matches.group('rgb'):
        return u'38;5;%d' % (16 + 36 * int(matches.group('red')) +
                             6 * int(matches.group('green')) +
                             int(matches.group('blue')))
    if matches.group('gray'):
        return u'38;5;%d' % (232 + int(matches.group('gray')))


def stringc(text, color, wrap_nonvisible_chars=False):
    """String in color."""

    if ANSIBLE_COLOR:
        color_code = parsecolor(color)
        fmt = u"\033[%sm%s\033[0m"
        if wrap_nonvisible_chars:
            # This option is provided for use in cases when the
            # formatting of a command line prompt is needed, such as
            # `ansible-console`. As said in `readline` sources:
            # readline/display.c:321
            # /* Current implementation:
            #         \001 (^A) start non-visible characters
            #         \002 (^B) end non-visible characters
            #    all characters except \001 and \002 (following a \001) are copied to
            #    the returned string; all characters except those between \001 and
            #    \002 are assumed to be `visible'. */
            fmt = u"\001\033[%sm\002%s\001\033[0m\002"
        return u"\n".join([fmt % (color_code, t) for t in text.split(u'\n')])
    else:
        return text


def colorize(lead, num, color):
    """ Print 'lead' = 'num' in 'color' """
    s = u"%s=%-4s" % (lead, str(num))
    if num != 0 and ANSIBLE_COLOR and color is not None:
        s = stringc(s, color)
    return s


def hostcolor(host, stats, color=True):
    if ANSIBLE_COLOR and color:
        if stats['failures'] != 0 or stats['unreachable'] != 0:
            return u"%-37s" % stringc(host, C.COLOR_ERROR)
        elif stats['changed'] != 0:
            return u"%-37s" % stringc(host, C.COLOR_CHANGED)
        else:
            return u"%-37s" % stringc(host, C.COLOR_OK)
    return u"%-26s" % host

### above directly copied from lib/ansible/utils/color.py
##############################################################################

class CallbackModule(CallbackModule_default):

    '''
    Design goals:
    - Print consolidated output that looks like a *NIX startup log
    - Defaults should avoid displaying unnecessary information wherever possible

    TODOs:
    - Only display task names if the task runs on at least one host
    - Add option to display all hostnames on a single line in the appropriate result color (failures may have a separate line)
    - Consolidate stats display
    - Don't show play name if no hosts found
    '''

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'community.general.smemshy'

    def _run_is_verbose(self, result):
        return ((self._display.verbosity > 0 or '_ansible_verbose_always' in result._result) and '_ansible_verbose_override' not in result._result)

    def _get_task_display_name(self, task):
        self.task_display_name = None
        display_name = task.get_name().strip().split(" : ")

        task_display_name = display_name[-1]
        if task_display_name.startswith("include"):
            return
        else:
            self.task_display_name = task_display_name

    def _preprocess_result(self, result):
        self.delegated_vars = result._result.get('_ansible_delegated_vars', None)
        self._handle_exception(result._result, use_stderr=self.get_option('display_failed_stderr'))
        self._handle_warnings(result._result)

    def _process_result_output(self, result, msg, print_stdio=True):
        task_host = result._host.get_name()
        task_result = f"{task_host} {msg}"

        # note, debug module always has verbose set
        if self._run_is_verbose(result):
            task_result = f"{task_host} {msg}: {self._dump_results(result._result, indent=4)}"
            return task_result

        # this doesn't work, but probably should.  see also ansible bug 18232
        #try: module_name = result._result['invocation']['module_name']
        #except: module_name = ''

        if self.delegated_vars:
            task_delegate_host = self.delegated_vars['ansible_host']
            task_result = f"{task_host} -> {task_delegate_host} {msg}"

        if print_stdio:
            if result._result.get('msg') and result._result.get('msg') != "All items completed":
                task_result += f" | msg: {to_text(result._result.get('msg'))}"
            if result._result.get('stdout'):
                task_result += f" | stdout: {result._result.get('stdout')}"
            if result._result.get('stderr'):
                task_result += f" | stderr: {result._result.get('stderr')}"

        return task_result

    def v2_playbook_on_task_start(self, task, is_conditional):
        self._get_task_display_name(task)
        if self.task_display_name is not None:
            if task.check_mode and self.get_option('check_mode_markers'):
                self._display.display(f"{self.task_display_name} (check mode)...")
            else:
                self._display.display(f"{self.task_display_name}...")

    def v2_playbook_on_handler_task_start(self, task):
        self._get_task_display_name(task)
        if self.task_display_name is not None:
            if task.check_mode and self.get_option('check_mode_markers'):
                self._display.display(f"{self.task_display_name} (via handler in check mode)... ")
            else:
                self._display.display(f"{self.task_display_name} (via handler)... ")

    def v2_playbook_on_play_start(self, play):
        name = play.get_name().strip()
        if play.check_mode and self.get_option('check_mode_markers'):
            if name and play.hosts:
                msg = f"\n>>> {name} (in check mode) on hosts: {','.join(play.hosts)} >>>"
            else:
                msg = "- check mode -"
        else:
            if name and play.hosts:
                msg = f"\n>>> {name} on hosts: {','.join(play.hosts)} >>>"
            else:
                msg = "---"

        self._display.display(msg)

    def v2_runner_on_skipped(self, result, ignore_errors=False):
        if self.get_option('display_skipped_hosts'):
            self._preprocess_result(result)
            display_color = C.COLOR_SKIP
            msg = "skipped"

            task_result = self._process_result_output(result, msg)
            self._display.display(f"  {task_result}", display_color)
        else:
            return

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._preprocess_result(result)
        display_color = C.COLOR_ERROR
        msg = "failed"
        item_value = self._get_item_label(result._result)
        if item_value:
            msg += f" | item: {item_value}"

        task_result = self._process_result_output(result, msg)
        self._display.display(f"  {task_result}", display_color, stderr=self.get_option('display_failed_stderr'))

    def v2_runner_on_ok(self, result, msg="ok", display_color=C.COLOR_OK):
        self._preprocess_result(result)

        result_was_changed = ('changed' in result._result and result._result['changed'])
        if result_was_changed:
            msg = "done"
            item_value = self._get_item_label(result._result)
            if item_value:
                msg += f" | item: {item_value}"
            display_color = C.COLOR_CHANGED
            print_stdio = True if self._run_is_verbose(result) else False
            task_result = self._process_result_output(result, msg, print_stdio=print_stdio)
            self._display.display(f"  {task_result}", display_color)
        elif self.get_option('display_ok_hosts') or self._run_is_verbose(result):
            task_result = self._process_result_output(result, msg)
            self._display.display(f"  {task_result}", display_color)

    def v2_runner_item_on_skipped(self, result):
        self.v2_runner_on_skipped(result)

    def v2_runner_item_on_failed(self, result):
        self.v2_runner_on_failed(result)

    def v2_runner_item_on_ok(self, result):
        self.v2_runner_on_ok(result)

    def v2_runner_on_unreachable(self, result):
        self._preprocess_result(result)

        msg = "unreachable"
        display_color = C.COLOR_UNREACHABLE
        task_result = self._process_result_output(result, msg)

        self._display.display(f"  {task_result}", display_color, stderr=self.get_option('display_failed_stderr'))

    def v2_on_file_diff(self, result):
        if result._task.loop and 'results' in result._result:
            for res in result._result['results']:
                if 'diff' in res and res['diff'] and res.get('changed', False):
                    diff = self._get_diff(res['diff'])
                    if diff:
                        self._display.display(diff)
        elif 'diff' in result._result and result._result['diff'] and result._result.get('changed', False):
            diff = self._get_diff(result._result['diff'])
            if diff:
                self._display.display(diff)

    def v2_playbook_on_stats(self, stats):
        self._display.display("\n===", screen_only=True)

        hosts = sorted(stats.processed.keys())
        for h in hosts:
            # TODO how else can we display these?
            t = stats.summarize(h)

            self._display.display(
                f"{hostcolor(h, t).strip()}: {"\x20".join(colorize('ok', t['ok'], C.COLOR_OK).split())}{colorize('changed', t['changed'], C.COLOR_CHANGED).strip()} "
                f"{colorize('unreachable', t['unreachable'], C.COLOR_UNREACHABLE).strip()} {"\x20".join(colorize('failed', t['failures'], C.COLOR_ERROR).split())}"
                f"{colorize('rescued', t['rescued'], C.COLOR_OK).strip()} {colorize('ignored', t['ignored'], C.COLOR_WARN).strip()}",
                screen_only=True
            )

            self._display.display(
                f"{hostcolor(h, t, False).strip()}: {"\x20".join(colorize('ok', t['ok'], None).split())} {colorize('changed', t['changed'], None).strip()} "
                f"{colorize('unreachable', t['unreachable'], None).strip()} {colorize('failed', t['failures'], None).strip()} {colorize('rescued', t['rescued'], None).strip()} "
                f"{colorize('ignored', t['ignored'], None).strip()}",
                log_only=True
            )
        if stats.custom and self.get_option('show_custom_stats'):
            self._display.banner("CUSTOM STATS: ")
            # per host
            # TODO: come up with 'pretty format'
            for k in sorted(stats.custom.keys()):
                if k == '_run':
                    continue
                stat_val = self._dump_results(stats.custom[k], indent=1).replace('\n', '')
                self._display.display(f'\t{k}: {stat_val}')

            # print per run custom stats
            if '_run' in stats.custom:
                self._display.display("", screen_only=True)
                stat_val_run = self._dump_results(stats.custom['_run'], indent=1).replace('\n', '')
                self._display.display(f'\tRUN: {stat_val_run}')
            self._display.display("", screen_only=True)

    def v2_playbook_on_no_hosts_matched(self):
        self._display.display("  No hosts found!", color=C.COLOR_DEBUG)

    def v2_playbook_on_no_hosts_remaining(self):
        self._display.display("  Ran out of hosts!", color=C.COLOR_ERROR)

    def v2_playbook_on_start(self, playbook):
        if context.CLIARGS['check'] and self.get_option('check_mode_markers'):
            self._display.display(f"Executing playbook {basename(playbook._file_name)} in check mode")
        else:
            self._display.display(f"Executing playbook {basename(playbook._file_name)}")

        # show CLI arguments
        if self._display.verbosity > 3:
            if context.CLIARGS.get('args'):
                self._display.display(f"Positional arguments: {' '.join(context.CLIARGS['args'])}",
                                      color=C.COLOR_VERBOSE, screen_only=True)

            for argument in (a for a in context.CLIARGS if a != 'args'):
                val = context.CLIARGS[argument]
                if val:
                    self._display.vvvv(f'{argument}: {val}')

    def v2_runner_retry(self, result):
        msg = f"  Retrying... ({result._result['attempts']} of {result._result['retries']})"
        if self._run_is_verbose(result):
            msg += f"Result was: {self._dump_results(result._result)}"
        self._display.display(msg, color=C.COLOR_DEBUG)
