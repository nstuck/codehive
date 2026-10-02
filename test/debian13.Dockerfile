# Debian 13 booted with systemd as PID 1, for running the tests on the system
# codehive is developed on. Used by the debian13 job in .github/workflows/ci.yml.
FROM debian:13
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus dbus-user-session libpam-systemd \
      sudo git python3 curl ca-certificates bats procps util-linux \
 && rm -rf /var/lib/apt/lists/*
# A login user like the one codehive runs as, with sudo like a typical server
RUN useradd -m -s /bin/bash tester \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
