# Ubuntu 22.04 like the work laptop: user Alex (UID 1001), corporate CA,
# system GnuPG, chezmoi, and Nix. Containers have no systemd, so Nix runs
# single-user here (the laptop uses the multi-user daemon).
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils sudo git zsh gnupg locales openssh-client \
 && rm -rf /var/lib/apt/lists/* \
 && locale-gen en_US.UTF-8

# Extra root CAs (Zscaler on the work network); the build script copies them in.
COPY ca/ /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates

RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

RUN useradd -m -u 1001 -s /bin/zsh Alex \
 && echo "Alex ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alex \
 && mkdir -m 0755 /nix && chown Alex /nix \
 && mkdir -p -m 700 /run/user/1001 && chown Alex /run/user/1001

USER Alex
# A login session's runtime directory (sops-nix keeps decrypted secrets there)
ENV USER=Alex HOME=/home/Alex LANG=en_US.UTF-8 XDG_RUNTIME_DIR=/run/user/1001 \
    NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    NIX_GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
WORKDIR /home/Alex

RUN curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon \
 && mkdir -p ~/.config/nix \
 && printf '%s\n' \
      'experimental-features = nix-command flakes' \
      'ssl-cert-file = /etc/ssl/certs/ca-certificates.crt' \
      'sandbox = false' \
      > ~/.config/nix/nix.conf
