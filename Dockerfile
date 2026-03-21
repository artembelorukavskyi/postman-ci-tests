FROM postman/newman:latest
WORKDIR /etc/newman
ENTRYPOINT ["newman"]