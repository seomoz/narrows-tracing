###
This server response to ui on a /vizc end point and returns queried JSON as reponse
###
express = require 'express'
bodyparser = require 'body-parser'
varz = require 'express-varz'
conf = require '../tracing_conf'
port = conf.vizc_server_port
vizJsonCreator = require './vizceral_json_file_creator_nodes'

server = express()
server.use bodyparser.json limit: '1mb'
server.use bodyparser.urlencoded extended: true

server.get '/vizc', (req, res, next) ->
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "X-Requested-With");
  vizJsonCreator.getJSON (err, data) ->
    console.log err if err
    res.write(data)
    res.end()

varz.setHttpServer server.listen port

console.log "Listening on port: #{port}"
