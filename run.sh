#!/usr/bin/env bash

#
# Ansible sometimes calls /bin/sh which does not support strap function naming conventions that use
# double colons (e.g. strap::foo::bar) per Google's
# [Shell Style Guide](https://google.github.io/styleguide/shell.xml?showone=Function_Names#Function_Names)
#
# Having bash-only functions with these naming conventions causes /bin/sh to barf, producing error messages
# like these:
#
#    /bin/sh: error importing function definition for 'strap::readval'
#    /bin/sh: error importing function definition for 'strap::github::api::request'
#    /bin/sh: error importing function definition for 'strap::fs::dirpath'
#    ... etc ...
#
# As a result well unset (remove) those functions from the current shell (which is created by Strap - it's not the
# user's shell that invokes strap) before invoking ansible so when it calls /bin/sh, we won't be overloaded
# with said error messages.
#
# NOTE: any strap function that would have been useful will NOT be available after this line:
unset -f $(compgen -A function strap)
# strap functions are no longer available at this point.  Now call ansible.

export ANSIBLE_ROLES_PATH="${HOME}/.strap/ansible/roles"
mkdir -p "${ANSIBLE_ROLES_PATH}"

# Since the Ansible 'control node' is the same as the 'target node' (i.e. localhost) for our use case of bootstrapping
# our own laptop, ensure that ansible tasks use the exact same python interpreter that we use to run ansible-playbook.
# This ensures that we have a consistent python runtime for everything during the ansible run.
#
# We do this by looking in the ansible-playbook executable script itself - and stripping the shebang which results in
# the python path.  Then we set that via the '-e' flag when invoking ansible playbook below.
ansible_python_interpreter="$(head -n1 "$(which ansible-playbook)" | sed 's/#!//g')"

ansible-galaxy install -r "${STRAP_HOOK_PACKAGE_DIR}/requirements.yml" -p "${ANSIBLE_ROLES_PATH}"
# STRAP_HOME and STRAP_HOOK_PACKAGE_DIR are set by strap before calling this run.sh script, so we can reference them:
ansible-playbook -i "${STRAP_HOME}/etc/ansible/hosts" \
                 -e "ansible_python_interpreter=${ansible_python_interpreter}" \
                 "${STRAP_HOOK_PACKAGE_DIR}/main.yml"
