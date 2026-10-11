# Демо-сервер для скриншотов vysh: Alpine + sshd, вход только по ключу.
FROM alpine:3.21

# Пароля у demo нет, но учётка не «заблокирована» (* вместо !):
# иначе sshd не пустит и по ключу.
RUN apk add --no-cache openssh bash htop fastfetch ncurses \
 && ssh-keygen -A \
 && adduser -D -s /bin/bash demo \
 && sed -i 's/^demo:!/demo:*/' /etc/shadow \
 && printf '\nPasswordAuthentication no\nPermitRootLogin no\nPrintMotd no\n' \
      >> /etc/ssh/sshd_config \
 && : > /etc/motd

COPY --chown=demo:demo bash_profile /home/demo/.bash_profile
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
