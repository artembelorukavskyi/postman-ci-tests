FROM postman/newman:latest
RUN npm install -g newman-reporter-htmlextra
WORKDIR /etc/newman
ENTRYPOINT ["newman"]