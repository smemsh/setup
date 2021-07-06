#
# build virtualenv to run ansible:
#
#   $ cd venv
#   $ make
#
# update dependencies:
#
#   $ vim requirements.in
#   $ make
#
# update venv's packaging tools to latest pypi versions:
#
#   $ make pkgup
#
###

PYBASE := /usr/local/bin/python3

venv: bin/python3 bin/pip-compile bin/ansible

bin/python3:
	$(PYBASE) -m venv --symlinks .

bin/ansible: requirements.txt
	bin/pip-sync -q
	touch bin/ansible

requirements.txt compile: requirements.in
	bin/pip-compile -q requirements.in

bin/pip-compile pkgup:
	bin/pip3 install -q -U pip wheel setuptools pip-tools

clean:
	rm -rf bin include lib lib64 pyvenv.cfg

rebuild: clean venv

.PHONY: venv pkgup compile clean rebuild
