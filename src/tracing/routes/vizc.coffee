###
This server response to ui on a /vizc end point and returns queried JSON as reponse
###
express = require 'express'
bodyparser = require 'body-parser'
varz = require 'express-varz'
conf = require '../../tracing_conf'
port = conf.vizc_server_port
vizJsonCreator = require '../vizceral_json_file_creator_nodes'

module.exports = (router) ->
    router.get '/vizc', (req, res, next) ->
        res.header('Access-Control-Allow-Origin', '*');
        vizJsonCreator.getJSON (err, data) ->
          res.json data
