ansible-role-sysadmin
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ansible role to configure a host as sysadmin-group-managed


description
------------------------------------------------------------------------------

- adds sane sudoers defaults for everyone (nopasswd, keepenv)
- creates sysadmin group 666 if dne (should bomb if exists and not 666)
- adds sysadmin group members with unrestricted sudo privs

| scott@smemsh.net
| https://github.com/smemsh/ansible-role-sysadmin
| http://spdx.org/licenses/GPL-2.0
