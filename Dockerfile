FROM node:5.6.0

MAINTAINER Manish Ranjan manish@moz.com

RUN apt-get update && \
  apt-get install -y wget git build-essential && \
  ln -s /usr/bin/nodejs /usr/bin/node && \
  mkdir -p /deploy/narrows-tracing/node_modules


WORKDIR /deploy/narrows-tracing

# Cache node_modules and source images separately
COPY . /deploy/narrows-tracing/

RUN npm install

RUN npm run build

COPY ./node_modules /deploy/narrows-tracing/node_modules

COPY package.json /deploy/narrows-tracing/

EXPOSE 7880

CMD ["npm", "start"]
