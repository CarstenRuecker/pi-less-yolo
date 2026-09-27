#!/bin/sh
set -e

# Ensure the runtime UID is registered in /etc/passwd with home = $HOME
# before starting pi. SSH calls getpwuid(3) and hard-fails without an entry;
# nss_wrapper is unavailable in Wolfi so we write directly.
# Podman synthesises its own UID line when none exists (home = host home +
# workdir suffix) and NSS returns the first match, so an existing line with
# the wrong home must be replaced, not skipped. /etc itself is not writable
# as the runtime UID, so the filtered copy lives in /tmp and is redirected
# into the existing world-writable /etc/passwd (0666).
uid="$(id -u)"
tmp="/tmp/passwd.${uid}.$$"
awk -F: -v uid="${uid}" '$3 != uid' /etc/passwd > "${tmp}" &&
    cat "${tmp}" > /etc/passwd || :
rm -f "${tmp}"
printf 'piuser:x:%d:%d:piuser:%s:/bin/sh\n' \
    "${uid}" "$(id -g)" "${HOME}" >> /etc/passwd || :

# Pass through to a shell when invoked via `pi:shell`; otherwise run pi.
case "${1:-}" in
    bash|sh) exec "$@" ;;
    *) exec pi "$@" ;;
esac
