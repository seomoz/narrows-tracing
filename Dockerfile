FROM node:5.6.0

MAINTAINER Manish Ranjan manish@moz.com

RUN apt-get update && \
  apt-get install -y wget git build-essential && \
  ln -s /usr/bin/nodejs /usr/bin/node && \
  mkdir -p /deploy/narrows-tracing/node_modules

COPY ./node_modules /deploy/narrows-tracing/node_modules
# Cache node_modules and source images separately
COPY . /deploy/narrows-tracing/

WORKDIR /deploy/narrows-tracing

RUN npm run build

EXPOSE 7880

CMD ["npm", "start"]
